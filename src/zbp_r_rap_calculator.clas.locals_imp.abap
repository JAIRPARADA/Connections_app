CLASS lhc_zr_rap_calculator DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Calculator
        RESULT result,
      CalculateCalcResult FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Calculator~CalculateCalcResult.
ENDCLASS.

CLASS lhc_zr_rap_calculator IMPLEMENTATION.

METHOD get_global_authorizations.
ENDMETHOD.


**************************************************************************
* Internal instance-bound action calculateTotalPrice
**************************************************************************
  METHOD CalculateCalcResult.

    " Read all relevant operand instances.
    READ ENTITIES OF zr_rap_calculator IN LOCAL MODE
    ENTITY Calculator
    FIELDS ( OperandA OperandB Operator )
    WITH CORRESPONDING #( keys )
    RESULT DATA(Calculations).

    LOOP AT Calculations ASSIGNING FIELD-SYMBOL(<Calculator>).
      IF <Calculator>-Operator = '+'.
        <Calculator>-CalcResult = <Calculator>-OperandA + <Calculator>-OperandB.
      ELSEIF <Calculator>-Operator = '-'.
        <Calculator>-CalcResult = <Calculator>-OperandA - <Calculator>-OperandB.
      ELSEIF <Calculator>-Operator = '*'.
        <Calculator>-CalcResult = <Calculator>-OperandA * <Calculator>-OperandB.
      ELSEIF <Calculator>-Operator = '/'.
        <Calculator>-CalcResult = <Calculator>-OperandA / <Calculator>-OperandB.
      ELSE.
        <Calculator>-CalcResult = 0.
      ENDIF.

    ENDLOOP.

    " write back the modified the result
    MODIFY ENTITIES OF zr_rap_calculator IN LOCAL MODE
    ENTITY Calculator
    UPDATE FIELDS ( CalcResult )
    WITH CORRESPONDING #( Calculations ).

  ENDMETHOD.

ENDCLASS.
