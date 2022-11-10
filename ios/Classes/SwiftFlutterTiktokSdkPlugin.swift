import Flutter
import UIKit
import TikTokOpenSDK
import Photos

public class SwiftFlutterTiktokSdkPlugin: NSObject, FlutterPlugin, PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        print(changeInstance)
    }
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.k9i/flutter_tiktok_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterTiktokSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setup":
      result(nil)
    case "login":
      login(call, result: result)
    case "shareGreenScreen":
        shareGreenScreenAPI(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
      return
    }
  }
  
  public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
      if TikTokOpenSDKApplicationDelegate.sharedInstance().application(app, open: url, sourceApplication: nil, annotation: "") {
          return true
      }
      return false
  }
    
    
    func shareGreenScreenAPI(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? String else {
          result(FlutterError.nilArgument)
          return
        }
        
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
          result(nil)
          return
        }
        
       
            if let asset = self.convertBase64StringToAsset(imageBase64String: args) {
                let success = self.shareGreenScreen(isVideo: false, asset: asset)
                result(success)
                return
        }
    
    }
    
    private func shareGreenScreen(isVideo: Bool, asset: String) -> Bool {
        
        var result: Bool = false
        let isInstalled = TikTokOpenSDKApplicationDelegate.sharedInstance().isAppInstalled()
        
    
        if(isInstalled) {
            
            var shareReq = TikTokOpenSDKShareRequest()
            shareReq.shareFormat = .greenScreen
            shareReq.mediaType = isVideo ? .video : .image
            
            var mediaLocalIdentifiers: [String] = []
            mediaLocalIdentifiers.append(asset)
            shareReq.localIdentifiers = mediaLocalIdentifiers
            //            shareReq.hashtag = "ERSocialShareManager"
            
            shareReq.send(completionBlock: { resp -> Void in
                print(resp)
                
                print(resp.shareState)
                print(resp.shareState.rawValue)
                print(resp.errCode.rawValue)
                print(resp.errString)
                print(resp.state)
                if resp.isSucceed {
                    result = true
                } else {
                    result = false
                }
            })
            return result
        } else {
            return false
        }
    }
    
    func convertBase64StringToAsset (imageBase64String:String) -> String? {
        //        var resultAsset: PHAsset?
        var localID: String?
        let imageData = Data(base64Encoded: imageBase64String)
        if let image = UIImage(data: imageData!) {
            do {
                PHPhotoLibrary.shared().register(self)
                if #available(iOS 14, *) {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        print(status.self)
                    }
                }
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let imgReq = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    localID =  imgReq.placeholderForCreatedAsset?.localIdentifier
                }
                //                let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localID!], options: .none)
                //
                //                resultAsset = asset.firstObject
                return localID
            } catch {
                print(error)
                return localID
            }
        }
        return localID
    }
  
  func login(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError.nilArgument)
      return
    }
    
    guard let scope = args["scope"] as? String else {
      result(FlutterError.failedArgumentField("scope", type: String.self))
      return
    }
    
    guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
      result(nil)
      return
    }
    
    let request = TikTokOpenSDKAuthRequest()
    let scopes = scope.split(separator: ",")
    let scopesSet = NSOrderedSet(array:scopes)
    request.permissions = scopesSet
    
    request.send(rootViewController, completion: { (resp : TikTokOpenSDKAuthResponse) -> Void in
      if resp.isSucceed {
        let resultMap: Dictionary<String,String?> = [
          "authCode": resp.code,
          "state": resp.state,
          "grantedPermissions": (resp.grantedPermissions?.array as? [String])?.joined(separator: ","),
        ]
        
        result(resultMap)
      } else {
        result(FlutterError(
          code: String(resp.errCode.rawValue),
          message: resp.errString,
          details: nil
        ))
      }
    })
  }
}

extension FlutterError {
  static let nilArgument = FlutterError(
    code: "argument.nil",
    message: "Expect an argument when invoking channel method, but it is nil.", details: nil
  )
  
  static func failedArgumentField<T>(_ fieldName: String, type: T.Type) -> FlutterError {
    return .init(
      code: "argument.failedField",
      message: "Expect a `\(fieldName)` field with type <\(type)> in the argument, " +
      "but it is missing or type not matched.",
      details: fieldName)
  }
}
