package main

import (
	"context"
	"errors"
	"io"
	"log"
	"net"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	event "github.com/dacut/lambda-network-proxy-event-go"
)

func handler(ctx context.Context, incoming event.ProxyEndpointEvent) error {
	log.Printf("Received event: %#v", incoming)
	if strings.HasPrefix(incoming.ProxyProtocol, "tcp") {
		return tcp_handler(ctx, incoming)
	} else {
		return udp_handler(ctx, incoming)
	}
}

func tcp_handler(ctx context.Context, incoming event.ProxyEndpointEvent) error {
	ip := net.ParseIP(incoming.ProxyAddress)
	proxyAddress := net.TCPAddr{IP: ip, Port: int(incoming.ProxyPort)}
	proxyConnection, err := net.DialTCP(incoming.ProxyProtocol, nil, &proxyAddress)
	if err != nil {
		log.Printf("Failed to connect to proxy: %v", err)
		return err
	}
	proxyConnection.SetNoDelay(true)
	defer proxyConnection.Close()

	// Send the nonce.
	log.Printf("Sending nonce %s to %s:%d", incoming.Nonce, incoming.ProxyAddress, incoming.ProxyPort)
	_, err = proxyConnection.Write([]byte(incoming.Nonce))
	if err != nil {
		log.Printf("Failed to send nonce: %v", err)
		return err
	}
	log.Printf("Nonce sent")

	// Keep reading packets and send them back.
	messageBuffer := make([]byte, 65536)
	for {
		n, err := proxyConnection.Read(messageBuffer)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			log.Printf("Failed to read from proxy: %v", err)
			return err
		}

		if n == 0 {
			break
		}

		log.Printf("Received %d message byte(s)", n)

		message := messageBuffer[:n]
		_, err = WriteBytes(proxyConnection, message)
		if err != nil {
			log.Printf("Failed to write to proxy: %v", err)
			return err
		}

		log.Printf("Send %d message byte(s)", n)
	}

	log.Printf("Connection closed")
	return nil
}

func udp_handler(ctx context.Context, incoming event.ProxyEndpointEvent) error {
	ip := net.ParseIP(incoming.ProxyAddress)
	proxyAddress := net.UDPAddr{IP: ip, Port: int(incoming.ProxyPort)}
	proxyConnection, err := net.ListenUDP(incoming.ProxyProtocol, nil)
	if err != nil {
		log.Printf("Failed to connect to proxy: %v", err)
		return err
	}
	defer proxyConnection.Close()

	// Send the nonce.
	log.Printf("Sending nonce %s to %s:%d", incoming.Nonce, incoming.ProxyAddress, incoming.ProxyPort)
	_, err = proxyConnection.WriteToUDP([]byte(incoming.Nonce), &proxyAddress)
	if err != nil {
		log.Printf("Failed to send nonce: %v", err)
		return err
	}
	log.Printf("Nonce sent")

	// Keep reading packets and send them back. Time out after 5 seconds of inactivity.
	messageBuffer := make([]byte, 65536)
	oobBuffer := make([]byte, 65536)
	for {
		proxyConnection.SetReadDeadline(time.Now().Add(5 * time.Second))
		n, oobn, _, remoteAddr, err := proxyConnection.ReadMsgUDP(messageBuffer, oobBuffer)
		if err != nil {
			var opError *net.OpError
			if isOpError := errors.As(err, &opError); isOpError && opError.Timeout() {
				log.Printf("Timing out after 5 seconds of inactivity")
				return nil
			}
			log.Printf("Failed to read from proxy: %v", err)
			return err
		}

		log.Printf("Received %d message byte(s) and %d out-of-band byte(s)", n, oobn)

		if remoteAddr.String() != proxyAddress.String() {
			log.Printf("Received packet from unexpected address: %v; expected %v", remoteAddr.String(), proxyAddress.String())
			continue
		}

		message := messageBuffer[:n]
		oob := oobBuffer[:oobn]

		n, oobn, err = proxyConnection.WriteMsgUDP(message, oob, &proxyAddress)
		if err != nil {
			log.Printf("Failed to write to proxy: %v", err)
			return err
		}

		log.Printf("Send %d message byte(s) and %d out-of-band byte(s)", n, oobn)
	}
}

func main() {
	lambda.StartWithContext(context.Background(), handler)
}
