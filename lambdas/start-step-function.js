const AWS = require('aws-sdk')
const sfn = new AWS.StepFunctions()

exports.handler = async (event) => {
  const { connectionId } = event.requestContext
  console.log({ connectionId })
  const execution = await sfn.startExecution({
    stateMachineArn: process.env.STATE_MACHINE_ARN,
    name: connectionId
  }).promise()
  console.log({ execution })
  return {
    statusCode: 200,
    body: JSON.stringify(execution),
  };
};
