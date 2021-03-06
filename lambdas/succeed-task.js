const AWS = require('aws-sdk')
const sfn = new AWS.StepFunctions()

exports.handler = async (event) => {
  const { taskToken, output } = JSON.parse(event.body)
  
  console.log({ taskToken, output })
  
  const success = await sfn.sendTaskSuccess({ taskToken, output: JSON.stringify(output) }).promise()
  
  console.log({ success })
  
  return {
      statusCode: 200,
      body: JSON.stringify(success),
  };
};
