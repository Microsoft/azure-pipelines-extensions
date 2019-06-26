import * as Reflux from 'reflux';
import {DataSourceActions} from '../actions/DataSourceActions';
import { DatasourceExtensionState,PayloadInfo } from '../states/DataSourceExtensionState';

export const defaultState: DatasourceExtensionState = {
    selectedDataSource:'',
    datasourcesInfo : null,
    displayInfo : null,
    currentInputParam:null,
    result:null,
    endpointDetails :null,
    parseError :null,
    executeError :null   
}

export class DataSourceStore extends Reflux.Store {
    listenables = DataSourceActions;
    state:DatasourceExtensionState = defaultState;
  
    init() {
        this.listenTo(DataSourceActions.GetDataSources, this.onGetDataSources);
        this.listenTo(DataSourceActions.SelectDataSource,this.onSelectDataSource);
        this.listenTo(DataSourceActions.UpdateDataSource,this.onUpdateDataSource);
        this.listenTo(DataSourceActions.UpdateDataSourceParameters,this.onUpdateDataSourceParameters);
        this.listenTo(DataSourceActions.ExecuteServiceEndpointRequest,this.onExecuteServiceEndpointRequest);
    }   
    
    private onGetDataSources(payload:PayloadInfo) {
        this.setState({
            datasourcesInfo:payload.datasourcesInfo,
            endpointDetails:payload.endpointDetails
        });                         
    }

    private onSelectDataSource(payload:PayloadInfo){
        this.setState({
                selectedDataSource: payload.selectedDataSource,
                currentInputParam:payload.currentInputParam,
                result:payload.result,
                parseError:payload.parseError,
                displayInfo : payload. displayInfo,
                executeError :payload.executeError
            });            
    }    
    
    private onUpdateDataSourceParameters(payload:PayloadInfo){
        this.setState({
            currentInputParam : {...this.state.currentInputParam, [payload.name]: payload.value},
            executeError :payload.executeError,
            parseError: payload.parseError,
            result:payload.result
        })            
    }


    private onUpdateDataSource(payload:PayloadInfo){
        this.setState({
            currentInputParam:payload.currentInputParam,
            result: payload.result,
            parseError :payload.parseError,
            executeError :payload.executeError,
            displayInfo : payload.displayInfo
        })               
    }
    
    private onExecuteServiceEndpointRequest(payload:PayloadInfo){
        this.setState({
            result: payload.result,
            executeError : payload.executeError,
            parseError :payload.parseError
        });
    }  
};