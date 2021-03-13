import React, { useState, useCallback, useEffect } from 'react';
import './App.css';
import useWebSocket, { ReadyState } from 'react-use-websocket';

function App() {
  const [socketUrl, setSocketUrl] = useState(null); //Public API that will echo messages sent to it back to the client
  const [messageHistory, setMessageHistory] = useState([]);
  const [sendMessage, lastMessage, readyState, getWebSocket] = useWebSocket(socketUrl);
 
  const handleClickChangeSocketUrl = useCallback(() => setSocketUrl('wss://mhyvm16uxb.execute-api.eu-west-2.amazonaws.com/v1'), []);
  const handleClickSendMessage = useCallback(() => sendMessage('Hello'), []);
 
  useEffect(() => {
    if (lastMessage !== null) {
    
      //getWebSocket returns the WebSocket wrapped in a Proxy. This is to restrict actions like mutating a shared websocket, overwriting handlers, etc
      const currentWebsocketUrl = getWebSocket().url;
      console.log('received a message from ', currentWebsocketUrl);
      
      setMessageHistory(prev => prev.concat(lastMessage));
    }
  }, [lastMessage]);
 
  const connectionStatus = {
    [ReadyState.CONNECTING]: 'Connecting',
    [ReadyState.OPEN]: 'Open',
    [ReadyState.CLOSING]: 'Closing',
    [ReadyState.CLOSED]: 'Closed',
    '-1': 'Not Connected'
  }[readyState];
 
  return (
    <div>
      <button onClick={handleClickChangeSocketUrl}>Start</button>
      <button onClick={handleClickSendMessage} disabled={readyState !== ReadyState.OPEN}>Click Me to send 'Hello'</button>
      <span>The WebSocket is currently {connectionStatus}</span>
      <ul>
        {messageHistory.map((message, idx) => <span key={idx}>{message.data}</span>)}
      </ul>
    </div>
  );
}

export default App;
