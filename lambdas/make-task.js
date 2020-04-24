const AWS = require('aws-sdk')
const http = new AWS.HttpClient()

exports.handler = async (event) => {
  console.log({ event })
  const { TaskToken, ConnectionId } = event
  //await postMessage(ConnectionId, { taskToken: TaskToken })
  console.log(Object.keys(http))
  const url = process.env.CONNECTION_URL

  const api = new AWS.ApiGatewayManagementApi({
    apiVersion: '2018-11-29',
    endpoint: url
  });
  
  const res = await api.postToConnection({
    ConnectionId,
    Data: JSON.stringify({ taskToken: TaskToken })
  }).promise()
  
  return {
      statusCode: 200,
      body: JSON.stringify('looking good'),
  }
};
