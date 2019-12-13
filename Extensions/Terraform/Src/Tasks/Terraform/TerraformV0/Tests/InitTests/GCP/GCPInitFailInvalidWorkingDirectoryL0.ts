import { TerraformCommandHandlerGCP } from '../../../src/provider/google';
import tl = require('azure-pipelines-task-lib');

let terraformCommandHandlerGCP: TerraformCommandHandlerGCP = new TerraformCommandHandlerGCP();

export async function run() {
    try {
        await terraformCommandHandlerGCP.init();
    } catch(error) {
        tl.setResult(tl.TaskResult.Failed, 'GCPInitFailInvalidWorkingDirectoryL0 should have succeeded but failed.');
    }
}

run();
