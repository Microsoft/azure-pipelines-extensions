import { TerraformCommandHandlerAWS } from '../../../src/provider/aws';
import tl = require('azure-pipelines-task-lib');

let terraformCommandHandlerAWS: TerraformCommandHandlerAWS = new TerraformCommandHandlerAWS();

export async function run() {
    try {
        const response = await terraformCommandHandlerAWS.destroy();
        if (response === 0) {
            tl.setResult(tl.TaskResult.Succeeded, 'AWSDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded.');
        } else{
            tl.setResult(tl.TaskResult.Failed, 'AWSDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
        }
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'AWSDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
    }
}

run();
