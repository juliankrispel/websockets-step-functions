const AWS = require('aws-sdk')
const sfn = new AWS.StepFunctions()

exports.handler = async (event) => {
    try {
        console.log({ event })
        const { connectionId } = event.requestContext
        console.log({ connectionId })
        const execution = await sfn.stopExecution({
            executionArn: `arn:aws:states:eu-west-2:492107414874:execution:MyStateMachine:${connectionId}`,
            cause: 'Client Disconnected'
        }).promise()
        console.log({ execution })
        return {
            statusCode: 200,
            body: JSON.stringify(execution),
        };
    } catch (err) {
        console.log(err)
        return {
            statusCode: 501,
            body: JSON.stringify('Error!'),
        };
    }
};
