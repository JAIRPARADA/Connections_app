CLASS zrapdev_calc_trav_elem_100 DEFINITION
PUBLIC
FINAL
CREATE PUBLIC .

  PUBLIC SECTION.

* interfaces IF_SADL_EXIT .
    INTERFACES if_sadl_exit_calc_element_read .
    CLASS-METHODS:
      calculate_trav_status_ind
        IMPORTING is_original_data TYPE zc_rap100_travel_m
        RETURNING VALUE(result)    TYPE zc_rap100_travel_m.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zrapdev_calc_trav_elem_100 IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~calculate.
    IF it_requested_calc_elements IS INITIAL.
      EXIT.
    ENDIF.

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_req_calc_elements>).
      CASE <fs_req_calc_elements>.
          "virtual elements from TRAVEL entity
        WHEN 'OVERALLSTATUSINDICATOR'.

          DATA lt_trav_original_data TYPE STANDARD TABLE OF zc_rap100_travel_m WITH DEFAULT KEY.
          lt_trav_original_data = CORRESPONDING #( it_original_data ).
          LOOP AT lt_trav_original_data ASSIGNING FIELD-SYMBOL(<fs_trav_original_data>).

            <fs_trav_original_data> = zrapdev_calc_trav_elem_100=>calculate_trav_status_ind( <fs_trav_original_data> ).

          ENDLOOP.

          ct_calculated_data = CORRESPONDING #( lt_trav_original_data ).

      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    IF iv_entity EQ 'ZC_RAP100_TRAVEL_M'. "Travel BO node
      LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_travel_calc_element>).
        CASE <fs_travel_calc_element>.
          WHEN 'OVERALLSTATUSINDICATOR'.
            APPEND 'OVERALLSTATUS' TO et_requested_orig_elements.

        ENDCASE.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD calculate_trav_status_ind.
    result = CORRESPONDING #( is_original_data ).

    "travel status indicator
    "(criticality: 1 = red | 2 = orange | 3 = green)
    CASE result-OverallStatus.
      WHEN 'X'.
        result-OverallStatusIndicator = 1.
      WHEN 'O'.
        result-OverallStatusIndicator = 2.
      WHEN 'A'.
        result-OverallStatusIndicator = 3.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
