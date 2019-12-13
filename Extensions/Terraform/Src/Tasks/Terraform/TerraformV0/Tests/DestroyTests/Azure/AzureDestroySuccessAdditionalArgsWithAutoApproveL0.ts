import { TerraformCommandHandlerAzureRM } from '../../../src/provider/azurerm';
import tl = require('azure-pipelines-task-lib');

let terraformCommandHandlerAzureRM: TerraformCommandHandlerAzureRM = new TerraformCommandHandlerAzureRM();

export async function run() {
    try {
        const response = await terraformCommandHandlerAzureRM.destroy();
        if (response === 0) {
            tl.setResult(tl.TaskResult.Succeeded, 'AzureDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded.');
        } else{
            tl.setResult(tl.TaskResult.Failed, 'AzureDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
        }
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'AzureDestroySuccessAdditionalArgsWithAutoApproveL0 should have succeeded but failed.');
    }
}

run();
