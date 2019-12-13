import { TerraformCommandHandlerGCP } from '../../../src/provider/google';
import tl = require('azure-pipelines-task-lib');

let terraformCommandHandlerGCP: TerraformCommandHandlerGCP = new TerraformCommandHandlerGCP();

export async function run() {
    try {
        const response = await terraformCommandHandlerGCP.destroy();
        if (response === 0) {
            tl.setResult(tl.TaskResult.Succeeded, 'GCPDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded.');
        } else{
            tl.setResult(tl.TaskResult.Failed, 'GCPDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
        }
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'GCPDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
    }
}

run();