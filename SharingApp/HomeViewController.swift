//
//  ViewController.swift
//  SharingApp
//
//  Created by Mahendra Vishwakarma on 05/09/20.
//  Copyright © 2020 Mahendra Vishwakarma. All rights reserved.
//

import UIKit
import MultipeerConnectivity

struct DataManager {
    var isSendData: Bool = false
    var marrFileData: Array<Data> = []
    var marrReceiveData:Array<Data> = []
    var noOfdata = 0
    var noOfDataSend = 0
    
}


class HomeViewController: UIViewController {

    var advertiser: MCAdvertiserAssistant?
    var session : MCSession?
    var peerID: MCPeerID?
    var browserVC: MCBrowserViewController?
    
    var dataManager: DataManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        dataManager = DataManager()
    }

    @IBAction func connectTapped(_ sender: Any) {
        if (self.session == nil) {
            self.setUpMultipeerConnection()
        }
        self.showBrowserViewController()
       
    }
    @IBAction func sendTapped(_ sender: Any) {
        self.sendData()
    }
    
    func setUpMultipeerConnection() {
        // setup peerID
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        
        //setup session
        guard let peerID = self.peerID else {
            return
        }
        self.session = MCSession(peer: peerID)
        
        // setup BrowserViewController
        guard let session = self.session else {
            return
            
        }
        self.browserVC  = MCBrowserViewController(serviceType: "chat", session: session)
        
        //setup advertiser
        
        self.advertiser = MCAdvertiserAssistant(serviceType: "chat", discoveryInfo: nil, session: session)
        
        // start peer connection
        self.advertiser?.start()
        
    }
    
    func showBrowserViewController() {
        if let browserObj = self.browserVC {
            browserObj.delegate = self
            self.present(browserObj, animated: true, completion: nil)
        }
    }
    func dismissBrowserViewController() {
        self.browserVC?.dismiss(animated: true, completion: {
            self.invokeAlert(strTitle: "Connected Successfully", body: "Both device connected successfully.")
        })
    }
    
    func stopWiFiSharing(isClear: Bool) {
        if isClear && self.session != nil{
            self.session?.disconnect()
            self.session = nil
            self.browserVC = nil
        }
    }
    
    
    func appendFileData() {
        var fileData = Data()
        for dt in dataManager?.marrFileData ?? [] {
            fileData.append(dt)
        }
        
        do {
            UIImageWriteToSavedPhotosAlbum(UIImage(data: fileData)!, nil, #selector(imageDidFinishSavingWithError(error:image:)), nil)
           try fileData.write(to: URL(string: NSHomeDirectory()+"Documents")!, options: .atomic)
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    @objc func imageDidFinishSavingWithError(error:Error,image:UIImage) {
        print(error.localizedDescription)
    }
    
    func invokeAlert(strTitle:String, body:String) {
        let alert = UIAlertController(title: strTitle, message: body, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default) { (alrt) in
            
        }
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func sendData() {
        dataManager?.marrFileData.removeAll()
        var sendData = UIImage(named: "mahendra")?.pngData()
        let dataLength = sendData?.count ?? 0
        let chunkSize = 100*1024
        var offset = 0
        
        repeat {
            let thisChunkSize = dataLength - offset > chunkSize ? chunkSize : dataLength - offset
            
            sendData!.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                 //Use `bytes` inside this closure
                let chunkData  = Data(bytesNoCopy: bytes + offset, count: thisChunkSize, deallocator: .none)
                self.dataManager?.marrFileData.append(chunkData)
                offset += thisChunkSize
            })
          
           
        }while(offset < dataLength)
        
        DispatchQueue.global(qos: .userInitiated).async {
           // self.dataManager?.noOfdata = self.dataManager?.marrFileData.count ?? 0
          //  self.dataManager?.noOfDataSend = 0
        }
       
      
        if(dataManager?.marrFileData.count ?? 0 > 0) {
            do{
                try self.session?.send((dataManager?.marrFileData.first)!, toPeers: self.session?.connectedPeers ?? [], with: MCSessionSendDataMode.reliable)
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
}


//MARK: - MCBrowserViewControllerDelegate
extension HomeViewController: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismissBrowserViewController()
        dataManager?.marrFileData.removeAll()
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
         dismissBrowserViewController()
    }
    
}

extension HomeViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
    }
    
    // Received a byte stream from remote peer
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
       
        
        if(data.count > 0) {
            if (data.count < 2) {
                dataManager?.noOfDataSend += 1
                if((dataManager?.noOfDataSend ?? 0) < (dataManager?.marrFileData.count ?? 0)) {
                    do{
                        try self.session?.send(dataManager?.marrFileData[dataManager?.noOfDataSend ?? 0] as! Data, toPeers: self.session?.connectedPeers ?? [], with: MCSessionSendDataMode.reliable)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                    
                } else {
                    do{
                        try self.session?.send(Data(base64Encoded: "file transfer done")!, toPeers: self.session?.connectedPeers ?? [], with: MCSessionSendDataMode.reliable)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                    
                }
                
            } else {
                if(String(data: data, encoding: .utf8) == "file transfer done") {
                    do{
                        try self.session?.send(Data(base64Encoded: "1")!, toPeers: self.session?.connectedPeers ?? [], with: MCSessionSendDataMode.reliable)
                        
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
            }
            
        }
    }
    
    // Start receiving a resource from remote peer
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
     // Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print(progress)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print(localURL?.absoluteString)
    }
    
    
}
