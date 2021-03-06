package flashwavrecorder {

  import flash.events.EventDispatcher;
  import flash.events.SampleDataEvent;
  import flash.utils.ByteArray;

  public class MicrophoneLevelForwarder extends EventDispatcher implements IMicrophoneEventForwarder  {

    private var sampleCalculator:SampleCalculator;

    public function MicrophoneLevelForwarder(sampleCalculator:SampleCalculator) {
      this.sampleCalculator = sampleCalculator;
    }

    public function handleMicSampleData(event:SampleDataEvent):void {
      var levelValue:Number = sampleCalculator.getHighestSample(ByteArray(event.data));
      dispatchLevelEvent(levelValue);
    }

    private function dispatchLevelEvent(level:Number):void {
      dispatchEvent(new MicrophoneLevelEvent(level));
    }

  }
}