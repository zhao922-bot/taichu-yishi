# 太初易筮

基于 Flutter 的《高岛易断》传统占筮应用。应用内的卦辞、爻辞与逐条《占断》来自随项目打包的 EPUB 提取数据，起筮过程按步骤展示，自动分签与用户滑动分签均在本机完成。

## 已实现的方法

- 周易传统筮法：以 49 策逐爻完成十八变，可出现多爻动。
- 49 签略筮法：依性别显示左手/右手顺序，三次分签定上卦、下卦与动爻。
- 八卦签 + 六爻签：依次抽上卦、下卦与动爻。
- 64 卦签 + 六爻签：先抽本卦，再抽动爻。
- 384 爻签：一次抽取同时确定本卦与动爻。

支持阴（夜色漆金）、阳（宣纸日光）和跟随系统三种界面样式。未完成的起筮会保存到本机并可恢复，也可以主动放弃本次起筮。

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

## 构建发布包

```powershell
flutter build windows --release
flutter build apk --release
flutter build appbundle --release
```

Android 正式构建需要签名配置和正式 keystore；示例文件见 `android/key.properties.example`。推荐将配置放在项目目录之外，并通过 `TAICHU_RELEASE_KEY_PROPERTIES` 指定：

```powershell
$env:TAICHU_RELEASE_KEY_PROPERTIES = 'C:\path\to\taichu-yishi-key.properties'
flutter build apk --release
```

不要将真实密码、keystore 或本机 `android/local.properties` 提交到版本库。

发布产物位置：

- Windows：`build/windows/x64/runner/Release/`
- APK：`build/app/outputs/flutter-apk/app-release.apk`
- AAB：`build/app/outputs/bundle/release/app-release.aab`

## 数据与隐私

卦象与《占断》数据随应用打包，不需要网络请求。问题文本、起筮进度和界面样式仅保存在用户设备本地。

本项目仅供传统文化学习与个人省思，不构成医疗、法律、投资或其他专业建议。
