# 메뉴 원가·마진 계산기

식자재 단가와 레시피를 입력하면 메뉴별 원가, 원가율, 판매 채널별 순이익을 계산하는 소규모 매장용 Flutter 앱입니다.

- 식자재 단가 자동 계산, 재료값을 바꾸면 모든 메뉴 원가가 즉시 다시 계산
- 원가율 높은 순 대시보드, 경고 기준을 넘는 메뉴는 빨간색
- 채널별 판매가·수수료·부자재를 반영한 순이익, 목표 원가율 기준 적정 판매가
- 판매가 부가세 포함 옵션 (공급가액 기준 계산)

Flutter + Riverpod + Firebase(익명 로그인, Cloud Firestore)

## 실행하기

Firebase 설정 파일은 저장소에 포함하지 않습니다. 본인 Firebase 프로젝트를 연결해서 만드세요.

1. Firebase 콘솔에서 프로젝트를 만들고 **Authentication → 익명 로그인**을 켜고 **Firestore 데이터베이스**를 만듭니다.
2. 앱을 연결합니다. `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json`이 생성됩니다.

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. 생성된 `firebase.json`에 `"firestore": {"rules": "firestore.rules"}`를 추가하고 보안 규칙을 배포합니다.

   ```bash
   firebase deploy --only firestore:rules
   ```

4. 실행합니다.

   ```bash
   flutter run
   ```

계산 로직 테스트는 Firebase 없이 실행됩니다.

```bash
flutter test
```
