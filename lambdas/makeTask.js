const AWS = require('aws-sdk')
const http = new AWS.HttpClient()

exports.handler = async (event) => {
    try {
        console.log({ event })
        const { TaskToken, ConnectionId } = event
        //await postMessage(ConnectionId, { taskToken: TaskToken })
        console.log(Object.keys(http))
        const url = `https://n1hygkq4hl.execute-api.eu-west-2.amazonaws.com/v1`

        const api = new AWS.ApiGatewayManagementApi({
            apiVersion: '2018-11-29',
            endpoint: url
        });
        
        const res = await api.postToConnection({
            ConnectionId,
            Data: JSON.stringify({ taskToken: TaskToken })
        }).promise()
        
        console.log({ res });
        
        return {
            statusCode: 200,
            body: JSON.stringify('looking good'),
        }
    } catch (err) {
        console.log(err)
        return {
            statusCode: 501,
            body: JSON.stringify('cant get this done sry'),
        }
    }
};
