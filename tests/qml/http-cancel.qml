import QtQuick
import Quickshell
import "Plugin" as Oma
QtObject {
 property Oma.Http http: Oma.Http {}
 property Timer check: Timer {
  interval:100;running:true
  onTriggered:{
   http.send({argv:["/usr/bin/sleep","1"],stdin:""},function(v){})
   http.send({argv:["/usr/bin/touch",Quickshell.env("XDG_RUNTIME_DIR")+"/must-not-run"],stdin:""},function(v){})
   cancelLater.start()
   finish.start()
  }
 }
 property Timer cancelLater: Timer {id:cancelLater;interval:50;onTriggered:http.cancel()}
 property Timer finish: Timer {id:finish;interval:1500;onTriggered:{console.log("CANCEL_PASS");Qt.quit()}}
}
