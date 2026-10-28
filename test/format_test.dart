import 'package:cost_test1/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('입력칸에 다시 채우는 사용량은 저장된 값을 그대로 보여준다', () {
    expect(amountText(200), '200');
    expect(amountText(12.5), '12.5');
    // 반올림되면 수정 화면에서 저장만 눌러도 사용량이 바뀐다
    expect(amountText(0.25), '0.25');
    expect(amountText(2.125), '2.125');
  });

  test('퍼센트 입력값에 부동소수 오차가 보이지 않는다', () {
    expect(rateInput(0.068), '6.8');
    expect(rateInput(0.07), '7'); // 0.07 * 100 = 7.000000000000001
    expect(rateInput(0.9), '90'); // 0.9 * 100 = 90.00000000000001
    expect(rateInput(0.29), '29'); // 0.29 * 100 = 28.999999999999996
  });
}
