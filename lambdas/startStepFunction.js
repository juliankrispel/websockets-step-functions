const AWS = require('aws-sdk')
const sfn = new AWS.StepFunctions()

exports.handler = async (event) => {
    console.log({ event })
    try {
        const { connectionId } = event.requestContext
        console.log({ connectionId })
        const execution = await sfn.startExecution({
            stateMachineArn: 'arn:aws:states:eu-west-2:492107414874:stateMachine:MyStateMachine',
            name: connectionId
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
