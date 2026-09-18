package chat

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
)

func TestServeConnReplaysHistoryAndBroadcasts(t *testing.T) {
	server, err := New(filepath.Join(t.TempDir(), "history.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	firstServer, firstClient := testConnection(t)
	go server.ServeConn(firstServer)
	firstReader := json.NewDecoder(bufio.NewReader(firstClient))

	// Registrar primero a Ana para que el servidor anuncie su ingreso.
	sendRequest(t, firstClient, Request{Type: "join", User: "ana"})

	// Leer notificación de ingreso del sistema.
	joinEvent := readEvent(t, firstReader)
	if joinEvent.User != "Sistema" {
		t.Fatalf("expected join event from Sistema, got %#v", joinEvent)
	}

	// Enviar el mensaje de Ana.
	sendRequest(t, firstClient, Request{Type: "message", User: "ana", Text: "hola"})

	// Leer el mensaje real enviado por Ana.
	event := readEvent(t, firstReader)
	if event.Text != "hola" {
		t.Fatalf("expected first message, got %#v", event)
	}

	secondServer, secondClient := testConnection(t)
	go server.ServeConn(secondServer)
	secondReader := json.NewDecoder(bufio.NewReader(secondClient))

	// Leer el evento de ingreso y el mensaje previamente almacenados.
	_ = readEvent(t, secondReader)
	replayed := readEvent(t, secondReader)
	if replayed.ID != event.ID {
		t.Fatalf("expected replayed event %d, got %d", event.ID, replayed.ID)
	}

	sendRequest(t, firstClient, Request{Type: "message", User: "luis", Text: "adios"})

	// Consumir el mensaje enviado por Luis.
	if received := readEvent(t, secondReader); received.Text != "adios" {
		t.Fatalf("expected broadcast, got %#v", received)
	}

	_ = firstClient.Close()
	_ = secondClient.Close()
}

func testConnection(t *testing.T) (net.Conn, net.Conn) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	serverConn := make(chan net.Conn, 1)
	go func() {
		conn, acceptErr := listener.Accept()
		if acceptErr == nil {
			serverConn <- conn
		}
	}()
	clientConn, err := net.Dial("tcp", listener.Addr().String())
	if err != nil {
		_ = listener.Close()
		t.Fatal(err)
	}
	_ = listener.Close()
	return <-serverConn, clientConn
}

func sendRequest(t *testing.T, conn net.Conn, request Request) {
	t.Helper()
	if err := json.NewEncoder(conn).Encode(request); err != nil {
		t.Fatal(err)
	}
}

func readEvent(t *testing.T, decoder *json.Decoder) Event {
	t.Helper()
	var event Event
	if err := decoder.Decode(&event); err != nil {
		t.Fatal(err)
	}
	return event
}
