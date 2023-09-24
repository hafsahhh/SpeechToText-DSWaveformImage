//
//  ViewController.swift
//  IOS-Swift-SpeechToText
//
//  Created by Siti Hafsah on 24/09/23.
//

import UIKit
import Speech
import Foundation
import AVFoundation
import NaturalLanguage
import DSWaveformImage
import DSWaveformImageViews

@available(iOS 12.0, *)
class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    @IBOutlet weak var startStopBtn: UIButton!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var waveFormView: WaveformLiveView!
    
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recorder: AVAudioRecorder?
    
    var lang: String = "id-ID"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startStopBtn.isEnabled = false
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        speechRecognizer?.delegate = self
        requestSpeechAuthorization()
        
        
        
        // Configure and start AVAudioRecorder
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ] as [String : Any]
            
            if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let audioFilename = url.appendingPathComponent("audio.wav")
                recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                recorder?.isMeteringEnabled = true
                recorder?.prepareToRecord()
            }
        } catch {
            print("AudioSession or AVAudioRecorder setup error: \(error.localizedDescription)")
        }
    }
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.startStopBtn.isEnabled = isButtonEnabled
            }
        }
    }
    
    @IBAction func startStopAct(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recorder?.stop() // Stop the audio recording
            
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Listen...", for: .normal)
        } else {
            startRecording()
            startStopBtn.setTitle("Stop", for: .normal)
        }
    }
    
    func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
            
            recorder?.record() // Start the audio recording
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
                    var isFinal = false
                    
                    if result != nil {
                        if let resultText = result?.bestTranscription.formattedString {
                            let languageIdentifier = NLLanguageRecognizer.dominantLanguage(for: resultText)
                            if let languageCode = languageIdentifier?.rawValue {
                                if languageCode == "id" {
                                    print("Indonesian Language")
                                } else if languageCode == "en" {
                                    print("English Language")
                                }
                            }
                            self.textView.text = resultText
                        }
                        
                        isFinal = (result?.isFinal)!
                        
                        // Panggil updateWaveformView() di sini untuk memperbarui tampilan gelombang
                        self.updateWaveformView()
                    }
                    
                    if error != nil || isFinal {
                        self.audioEngine.stop()
                        self.recorder?.stop() // Stop the audio recording
                        
                        let inputNode = self.audioEngine.inputNode
                        inputNode.removeTap(onBus: 0)
                        
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        
                        self.startStopBtn.isEnabled = true
                    }
                })
            
            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            
            do {
                try audioEngine.start()
            } catch {
                print("audioEngine couldn't start because of an error.")
            }
            
            textView.text = "Say something, I'm listening!"
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
    }
    
    
    func updateWaveformView() {
        recorder?.updateMeters()
        let currentAmplitude = 1 - pow(10, (recorder?.averagePower(forChannel: 0) ?? 0) / 20)

        // Tambahkan sampel ke tampilan gelombang
        waveFormView.add(sample: currentAmplitude)
        waveFormView.configuration = waveFormView.configuration.with(
            style: Waveform.Style.striped(.init(color: .red, width: 3, spacing: 2))
            
        )
        // Atur animasi berdasarkan tingkat suara
        UIView.animate(withDuration: 0.005) {
            if currentAmplitude > 0.01 { // Ubah ambang sesuai kebutuhan
                self.waveFormView.alpha = 1.0
            } else {
                self.waveFormView.alpha = 0.0
            }
        }
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopBtn.isEnabled = true
        } else {
            startStopBtn.isEnabled = false
        }
    }
    
    
}
