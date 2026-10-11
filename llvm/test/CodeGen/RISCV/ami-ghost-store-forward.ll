; RUN: llc -mtriple=riscv32 -O1 -riscv-enable-ami-linearization=true \
; RUN:   -riscv-ami-general-linearization=false -stop-before=remove-branch-pseudos \
; RUN:   %s -o - | FileCheck %s

@v = internal global i32 0, align 4

define dso_local secret(1) i32 @ghost_store(i32 noundef secret(1) %value,
                                            i32 noundef %bound) {
entry:
  store volatile i32 0, ptr @v, align 4
  %cmp = icmp slt i32 %value, %bound
  br i1 %cmp, label %then, label %exit

then:
  store volatile i32 %value, ptr @v, align 4
  br label %exit

exit:
  %result = load volatile i32, ptr @v, align 4
  ret i32 %result
}

; CHECK-LABEL: name:            ghost_store
; CHECK:         [[TMP:\$x[0-9]+]] = ADDI
; CHECK-NEXT:    GLW{{.*}}[[TMP]]
; CHECK-NEXT:    SW{{.*}}[[TMP]]
; CHECK-NOT:     = GLW
