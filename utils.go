package main

import "io"

func WriteBytes(w io.Writer, b []byte) (int, error) {
	totalWritten := 0
	for totalWritten < len(b) {
		n, err := w.Write(b[totalWritten:])
		if err != nil {
			return totalWritten, err
		}

		totalWritten += n
	}

	return totalWritten, nil
}
