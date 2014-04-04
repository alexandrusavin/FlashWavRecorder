package flashwavrecorder {

  import flash.display.DisplayObject;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.StatusEvent;
  import flash.external.ExternalInterface;
  import flash.media.Microphone;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import com.demonsters.debugger.MonsterDebugger;

  public class RecorderJSInterface {

    public static var READY:String = "ready";

    public static var NO_MICROPHONE_FOUND:String = "no_microphone_found";
    public static var MICROPHONE_USER_REQUEST:String = "microphone_user_request";
    public static var MICROPHONE_CONNECTED:String = "microphone_connected";
    public static var MICROPHONE_NOT_CONNECTED:String = "microphone_not_connected";
    public static var MICROPHONE_ACTIVITY:String = "microphone_activity";
    public static var MICROPHONE_LEVEL:String = "microphone_level";
    public static var MICROPHONE_SAMPLES:String = "microphone_samples";

    public static var ENCODE_BEGIN:String = "encode_begin";
    public static var ENCODE_COMPLETE:String = "encode_complete";

    public static var RECORDING:String = "recording";
    public static var RECORDING_STOPPED:String = "recording_stopped";

    public static var OBSERVING_LEVEL:String = "observing_level";
    public static var OBSERVING_LEVEL_STOPPED:String = "observing_level_stopped";

    public static var OBSERVING_SAMPLES:String = "observing_level";
    public static var OBSERVING_SAMPLES_STOPPED:String = "observing_level_stopped";

    public static var PLAYING:String = "playing";
    public static var STOPPED:String = "stopped";

    public static var SAVE_PRESSED:String = "save_pressed";
    public static var SAVING:String = "saving";
    public static var SAVED:String = "saved";
    public static var SAVE_FAILED:String = "save_failed";
    public static var SAVE_PROGRESS:String = "save_progress";

    public var recorder:MicrophoneRecorder;
    public var eventHandler:String = "microphone_recorder_events";
    public var uploadUrl:String;
    public var uploadFormData:Array;
    public var uploadFieldName:String;
    public var saveButton:DisplayObject;

    public function RecorderJSInterface() {
      MonsterDebugger.trace(this, "Init of the ExternalInterface.");
      this.recorder = new MicrophoneRecorder();
      
      if(ExternalInterface.available && ExternalInterface.objectID) {
        MonsterDebugger.trace(this, "Adding JS callbacks.");
        ExternalInterface.addCallback("record", record);
        ExternalInterface.addCallback("observeLevel", observeLevel);
        ExternalInterface.addCallback("stopObservingLevel", stopObservingLevel);
        ExternalInterface.addCallback("observeSamples", observeSamples);
        ExternalInterface.addCallback("stopObservingSamples", stopObservingSamples);
        ExternalInterface.addCallback("playBack", playBack);
        ExternalInterface.addCallback("playBackFrom", playBackFrom);
        ExternalInterface.addCallback("stopPlayBack", stopPlayBack);
        ExternalInterface.addCallback("pausePlayBack", pausePlayBack);
        ExternalInterface.addCallback("duration", duration);
        ExternalInterface.addCallback("getCurrentTime", getCurrentTime);
        ExternalInterface.addCallback("init", init);
        ExternalInterface.addCallback("permit", requestMicrophoneAccess);
        ExternalInterface.addCallback("configure", configureMicrophone);
        ExternalInterface.addCallback("show", show);
        ExternalInterface.addCallback("hide", hide);
        ExternalInterface.addCallback("update", update);
        ExternalInterface.addCallback("setUseEchoSuppression", setUseEchoSuppression);
        ExternalInterface.addCallback("setLoopBack", setLoopBack);
        ExternalInterface.addCallback("getMicrophone", getMicrophone);
      }
      MonsterDebugger.trace(this, "Adding event listners.");
      this.recorder.addEventListener(MicrophoneRecorder.SOUND_COMPLETE, playComplete);
      this.recorder.addEventListener(MicrophoneRecorder.PLAYBACK_STARTED, playbackStarted);
      this.recorder.addEventListener(MicrophoneRecorder.ACTIVITY, microphoneActivity);
      this.recorder.addEventListener(MicrophoneRecorder.ENCODE_BEGIN, encodeStared);
      this.recorder.addEventListener(MicrophoneRecorder.ENCODE_COMPLETE, encodeComplete);
      this.recorder.levelForwarder.addEventListener(MicrophoneLevelEvent.LEVEL_VALUE, microphoneLevel);
      this.recorder.samplesForwarder.addEventListener(MicrophoneSamplesEvent.RAW_SAMPLES_DATA, microphoneSamples);
    }

    public function ready(width:int, height:int):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.READY, width, height);
      MonsterDebugger.trace(this, "Ready callback called.");
      if (!this.recorder.mic.isMuted()) {
        onMicrophoneStatus(new StatusEvent(StatusEvent.STATUS, false, false, "Microphone.Unmuted", "status"));
      }
    }

    public function show():void {
      if(saveButton) {
        saveButton.visible = true;
      }
    }
    public function hide():void {
      if(saveButton) {
        saveButton.visible = false;
      }
    }

    private function playbackStarted(event:Event):void {
      ExternalInterface.call(this.eventHandler, MicrophoneRecorder.PLAYBACK_STARTED, this.recorder.currentSoundName, this.recorder.latency);
    }

    private function playComplete(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.STOPPED, this.recorder.currentSoundName);
    }

    private function microphoneActivity(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_ACTIVITY, this.recorder.mic.getActivityLevel());
    }

    private function encodeStared(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.ENCODE_BEGIN);
    }

    private function encodeComplete(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.ENCODE_COMPLETE);
    }

    private function microphoneLevel(event:MicrophoneLevelEvent):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_LEVEL, event.levelValue);
    }

    private function microphoneSamples(event:MicrophoneSamplesEvent):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_SAMPLES, event.samples);
    }

    public function init(url:String=null, fieldName:String=null, formData:Array=null):void {
      MonsterDebugger.trace(this, "uploadUrl: " + url);
      this.uploadUrl = url;
      this.uploadFieldName = fieldName;
      this.update(formData);
    }

    public function update(formData:Array=null):void {
      this.uploadFormData = [];
      if(formData) {
        for(var i:int=0; i<formData.length; i++) {
          var data:Object = formData[i];
          this.uploadFormData.push(MultiPartFormUtil.nameValuePair(data.name, data.value));
        }
      }
       MonsterDebugger.trace(this, this);
    }

    public function isMicrophoneAvailable():Boolean {
      if(! this.recorder.mic.isMuted()) {
        return true;
      } else if(Microphone.names.length == 0) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.NO_MICROPHONE_FOUND);
      } else {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_USER_REQUEST);
      }
      return false;
    }

    public function requestMicrophoneAccess():void {
      this.recorder.mic.addEventListener(StatusEvent.STATUS, onMicrophoneStatus);
      this.recorder.mic.setLoopBack(true);
    }

    private function onMicrophoneStatus(event:StatusEvent):void {
      this.recorder.mic.setLoopBack(false);
      if(event.code == "Microphone.Unmuted") {
        this.configureMicrophone();
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_CONNECTED, this.recorder.mic);
      } else {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.MICROPHONE_NOT_CONNECTED);
      } 
    }

    public function configureMicrophone(rate:int=22, gain:int=100, silenceLevel:Number=0, silenceTimeout:int=4000):void {
      this.recorder.mic.setRate(rate);
      this.recorder.mic.setGain(gain);
      this.recorder.mic.setSilenceLevel(silenceLevel, silenceTimeout);
    }

    public function setUseEchoSuppression(useEchoSuppression:Boolean):void {
      this.recorder.mic.setUseEchoSuppression(useEchoSuppression);
    }

    public function setLoopBack(state:Boolean):void {
      this.recorder.mic.setLoopBack(state);
    }

    public function getMicrophone():MicrophoneWrapper {
      return this.recorder.mic;
    }

    public function record(name:String, filename:String=null):Boolean {
      if(! this.isMicrophoneAvailable()) {
        return false;
      }

      if(this.recorder.recording) {
        this.recorder.stop();
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.RECORDING_STOPPED, this.recorder.currentSoundName, this.recorder.duration());
      } else {
        this.recorder.record(name, filename);
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.RECORDING, this.recorder.currentSoundName);
      }

      return this.recorder.recording;
    }

    public function observeLevel():Boolean {
      var succeed:Boolean = enableEventObservation(this.recorder.levelObserverAttacher);
      if (succeed) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.OBSERVING_LEVEL);
      }
      return succeed;
    }

    public function stopObservingLevel():Boolean {
      var succeed:Boolean = disableEventObservation(this.recorder.levelObserverAttacher);
      if (succeed) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.OBSERVING_LEVEL_STOPPED);
      }
      return succeed;
    }

    public function observeSamples():Boolean {
      var succeed:Boolean = enableEventObservation(this.recorder.samplesObserverAttacher);
      if (succeed) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.OBSERVING_SAMPLES);
      }
      return succeed;
    }

    public function stopObservingSamples():Boolean {
      var succeed:Boolean = disableEventObservation(this.recorder.samplesObserverAttacher);
      if (succeed) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.OBSERVING_SAMPLES_STOPPED);
      }
      return succeed;
    }

    public function playBack(name:String):Boolean {
      if(this.recorder.playing) {
        this.recorder.stop();
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.STOPPED, this.recorder.currentSoundName);
      } else {
        this.recorder.playBack(name);
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.PLAYING, this.recorder.currentSoundName);
      }

      return this.recorder.playing;
    }

    public function playBackFrom(name:String, time:Number):Boolean {
      if(this.recorder.playing) {
        this.recorder.stop();
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.STOPPED, this.recorder.currentSoundName);
      }
      this.recorder.playBackFrom(name, time);
      if (this.recorder.playing) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.PLAYING, this.recorder.currentSoundName);
      }
      return this.recorder.playing;
    }

    public function pausePlayBack(name:String):void {
      if(this.recorder.playing) {
        this.recorder.pause(name);
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.STOPPED, this.recorder.currentSoundName);
      }
    }

    public function stopPlayBack():void {
      if(this.recorder.recording) {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.RECORDING_STOPPED, this.recorder.currentSoundName, this.recorder.duration());
      } else {
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.STOPPED, this.recorder.currentSoundName);
      }
      this.recorder.stop();
    }

    public function duration(name:String):Number {
      return this.recorder.duration(name);
    }

    public function getCurrentTime(name:String):Number {
      return this.recorder.getCurrentTime(name);
    }

    public function save():Boolean {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVE_PRESSED, this.recorder.currentSoundName);
      try {
        _save(this.recorder.currentSoundName, this.recorder.currentSoundFilename);
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVING, this.recorder.currentSoundName);
      } catch(e:Error) {
        MonsterDebugger.trace(this, e);
        MonsterDebugger.trace(this, this.recorder.currentSoundName);
        MonsterDebugger.trace(this, this.recorder.currentSoundFilename);
        ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVE_FAILED, this.recorder.currentSoundName, e.message);
        return false;
      }
      return true;
    }

    private function enableEventObservation(eventObserverAttacher:MicrophoneEventObserverAttacher):Boolean {
      if (!this.isMicrophoneAvailable()) {
        return false;
      }
      if (!eventObserverAttacher.observing) {
        eventObserverAttacher.startObserving();
      }
      return eventObserverAttacher.observing;
    }

    private function disableEventObservation(eventObserverAttacher:MicrophoneEventObserverAttacher):Boolean {
      if (eventObserverAttacher.observing) {
        eventObserverAttacher.stopObserving();
      }
      return eventObserverAttacher.observing;
    }

    private function _save(name:String, filename:String):void {
      MonsterDebugger.trace(this, "Uploading...");
      var boundary:String = MultiPartFormUtil.boundary();

      try {
      this.uploadFormData.push( MultiPartFormUtil.fileField(this.uploadFieldName, this.recorder.getEncodedBytes(), filename, "audio/ogg") );
      var request:URLRequest = MultiPartFormUtil.request(this.uploadFormData);
      this.uploadFormData.pop();
      } catch (e:Error) {
        MonsterDebugger.trace(this, e);
      }
      request.url = this.uploadUrl;
      MonsterDebugger.trace(this, request);

      var loader:URLLoader = new URLLoader();
      loader.addEventListener(Event.COMPLETE, onSaveComplete);
      loader.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
      loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
      loader.addEventListener(ProgressEvent.PROGRESS, onProgress);
      try {
        loader.load(request);
      } catch (e:Error) {
        MonsterDebugger.trace(this, e);
      }
    }

    private function onSaveComplete(event:Event):void {
      var loader:URLLoader = URLLoader(event.target);
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVED, this.recorder.currentSoundName, loader.data);
    }

    private function onIOError(event:Event):void {
      MonsterDebugger.trace(this, IOErrorEvent(event));
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVE_FAILED, this.recorder.currentSoundName, IOErrorEvent(event).text);
    }

    private function onSecurityError(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVE_FAILED, this.recorder.currentSoundName, SecurityErrorEvent(event).text);
    }

    private function onProgress(event:Event):void {
      ExternalInterface.call(this.eventHandler, RecorderJSInterface.SAVE_PROGRESS, this.recorder.currentSoundName, ProgressEvent(event).bytesLoaded, ProgressEvent(event).bytesTotal);
    }
  }
}
