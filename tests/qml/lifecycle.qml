import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
QtObject {
    id: root
    property var config: ({bar:{id:"omarchy.bar",layout:{left:[],center:[],right:[]}},plugins:[]})
    property Services.PluginRegistry registry: Services.PluginRegistry {
        shellConfigProvider: function(){return root.config}
        shellConfigMutator: function(mutate){const next=JSON.parse(JSON.stringify(root.config));mutate(next);root.config=next;state.setText(JSON.stringify(next))}
    }
    property FileView state: FileView {path:Quickshell.env("HOME")+"/.config/omarchy/shell.json";printErrors:false}
    property Loader widget: Loader {
        active: root.registry.inBar("io.github.onurbyte.omamonero") && !!root.registry.installedPlugins["io.github.onurbyte.omamonero"]
        source: active?"file://"+root.registry.installedPlugins["io.github.onurbyte.omamonero"].__sourceDir+"/"+root.registry.installedPlugins["io.github.onurbyte.omamonero"].entryPoints.barWidget:""
    }
    property IpcHandler ipc: IpcHandler {
        target:"shell"
        function ping():string{return "ok"}
        function rescanPlugins():void{root.registry.rescan()}
        function setPluginEnabled(id:string,enabled:string):string{return root.registry.setEnabled(id,enabled==="true")?"ok":"unknown"}
        function enablePlugin(id:string,placement:string):string{return root.registry.setEnabled(id,true,JSON.parse(placement||"{}"))?"ok":root.registry.lastEnableError||"unknown"}
        function listPlugins():string{const out=[];for(const id in root.registry.installedPlugins){const m=root.registry.installedPlugins[id];out.push({id:id,name:m.name,kinds:m.kinds,enabled:root.registry.inBar(id),firstParty:false})}return JSON.stringify(out)}
        function widgetInfo():string{return JSON.stringify({status:root.widget.status,source:String(root.widget.source),view:root.widget.item?root.widget.item.view:null})}
    }
}
