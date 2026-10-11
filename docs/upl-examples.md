# Ví dụ kiểm thử UPL

Chạy từ thư mục gốc dự án: `xmake`, rồi:

``` sh
xmake run compiler < tests/grammar_valid.src
xmake run compiler < tests/error_prone.src
```

## 1. Hợp lệ - `tests/grammar_valid.src`

```
begin
    int x=0;
    int y=(x+1)*2;
    bool a=y>=2;
    // In gia tri boolean
    if (a) then {
        print(y);
    } else {
        x=x+1;
    }
    /* Vong lap thuc hien it nhat mot lan */
    do {
        x=x+1;
    } while (3>x);
    for (int i=0; 3>i; i=i+1) {
        print(i);
    }
    print(a==true);
end
```

Kết quả: mã thoát 0, xuất AST dạng JSON. Bao gồm khai báo, gán, `if/else`, `do/while`, `for`, phép toán và comment.

## 2. Sai cú pháp - `tests/grammar_errors.src`

```
begin
    int x=;
    print(1+);
    print(2);
end
```

Kết quả: 2 lỗi tại dòng 2 và 3; mã thoát 1; không xuất AST.

## 3. Nhiều lỗi - `tests/error_prone.src`

Tệp 34 dòng, mỗi lỗi có chú thích: thiếu `;`, thiếu toán hạng, thiếu `)`, định danh sai và ký tự `@`.

| Loại          | Dòng báo lỗi                     |
|:--------------|:---------------------------------|
| 9 lỗi cú pháp | 7, 9, 10, 13, 16, 21, 23, 26, 32 |
| 3 lỗi từ vựng | 29, 30, 31                       |

Kết quả: mã thoát 1, không xuất AST. Parser phục hồi đến câu lệnh cuối `print(12345);`. Lỗi thiếu `;` ở dòng 8 được báo tại token kế tiếp ở dòng 9. Kiểm chứng bằng C++: `xmake test`.

**Giới hạn:** các ví dụ kiểm tra từ vựng và cú pháp; parser chưa kiểm tra kiểu hay khai báo biến.
