import { Terraform as terraformCommandHandlerAzureRM } from '../../../src/terraform';
import tl = require('azure-pipelines-task-lib');

let backend:any = "azurerm"
let provider:any = "azurerm"
let TerraformCommandHandlerAzureRM: terraformCommandHandlerAzureRM = new terraformCommandHandlerAzureRM(backend, provider);

export async function run() {
    try {
        const response = await TerraformCommandHandlerAzureRM.validate();
        if (response === 0) {
            tl.setResult(tl.TaskResult.Succeeded, 'AzureValidateSuccessEmptyWorkingDirL0 should have succeeded.');
        } else{
            tl.setResult(tl.TaskResult.Failed, 'AzureValidateSuccessEmptyWorkingDirL0 should have succeeded but failed.');
        }
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'AzureValidateSuccessEmptyWorkingDirL0 should have succeeded but failed.');
    }
}

run();