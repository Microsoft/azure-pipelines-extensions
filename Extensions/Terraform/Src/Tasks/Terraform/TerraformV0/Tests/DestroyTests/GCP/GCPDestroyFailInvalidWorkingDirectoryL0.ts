import { Terraform as TerraformCommandHandlerGCP } from '../../../src/terraform';
import tl = require('azure-pipelines-task-lib');

let backend:any = "gcp"
let provider:any = "gcp"
let terraformCommandHandlerGCP: TerraformCommandHandlerGCP = new TerraformCommandHandlerGCP(backend,provider);

export async function run() {
    try {
        await terraformCommandHandlerGCP.destroy();
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'GCPDestroyFailInvalidWorkingDirectoryL0 should have succeeded but failed with error.');
    }
}

run();