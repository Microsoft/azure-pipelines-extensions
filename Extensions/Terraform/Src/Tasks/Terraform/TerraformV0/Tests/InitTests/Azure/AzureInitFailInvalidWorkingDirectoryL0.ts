import { TerraformCommandHandlerAzureRM } from '../../../src/provider/azurerm';
import tl = require('azure-pipelines-task-lib');

let terraformCommandHandlerAzureRM: TerraformCommandHandlerAzureRM = new TerraformCommandHandlerAzureRM();

export async function run() {
    try {
        await terraformCommandHandlerAzureRM.init();
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'AzureInitFailInvalidWorkingDirectoryL0 should have succeeded but failed with error.');
    }
}

run();