CLASS zrapdev_calc_book_elem_100 DEFINITION
PUBLIC
FINAL
CREATE PUBLIC .
  PUBLIC SECTION.
* interfaces IF_SADL_EXIT .
    INTERFACES if_sadl_exit_calc_element_read .
    CLASS-METHODS:
      calculate_days_to_flight
        IMPORTING is_original_data TYPE zc_rap100_book_m
        RETURNING VALUE(result)    TYPE zc_rap100_book_m.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zrapdev_calc_book_elem_100 IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~calculate.
    IF it_requested_calc_elements IS INITIAL.
      EXIT.
    ENDIF.

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_req_calc_elements>).

      CASE <fs_req_calc_elements>.
          "virtual elements from BOOKING entity
        WHEN 'INITIALDAYSTOFLIGHT' OR 'REMAININGDAYSTOFLIGHT'
        OR 'DAYSTOFLIGHTINDICATOR' OR 'BOOKINGSTATUSINDICATOR'.

          DATA lt_book_original_data TYPE STANDARD TABLE OF zc_rap100_book_m WITH DEFAULT KEY.
          lt_book_original_data = CORRESPONDING #( it_original_data ).
          LOOP AT lt_book_original_data ASSIGNING FIELD-SYMBOL(<fs_book_original_data>).

            <fs_book_original_data> = zrapdev_calc_book_elem_100=>calculate_days_to_flight( <fs_book_original_data> ).

          ENDLOOP.

          ct_calculated_data = CORRESPONDING #( lt_book_original_data ).

      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    IF iv_entity EQ 'ZC_RAP100_BOOK_M'. "Booking BO node
      LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_booking_calc_element>).
        CASE <fs_booking_calc_element>.
          WHEN 'INITIALDAYSTOFLIGHT'.
            COLLECT `BOOKINGDATE` INTO et_requested_orig_elements.
            COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
          WHEN 'REMAININGDAYSTOFLIGHT'.
            COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
          WHEN 'DAYSTOFLIGHTINDICATOR'.
            COLLECT `FLIGHTDATE` INTO et_requested_orig_elements.
          WHEN 'BOOKINGSTATUSINDICATOR'.
            COLLECT `BOOKINGSTATUS` INTO et_requested_orig_elements.

        ENDCASE.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD calculate_days_to_flight.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    result = CORRESPONDING #( is_original_data ).

    "VE InitialDaysToFlight: initial days to flight
    DATA(initial_days) = result-FlightDate - result-BookingDate.
    IF initial_days > 0 AND initial_days < 999.
* IF initial_days > 0 .
      result-InitialDaysToFlight = initial_days.
    ELSE.
      result-InitialDaysToFlight = 0.
    ENDIF.

    "VE RemainingDaysToFlight: remaining days to flight
    DATA(remaining_days) = result-FlightDate - today.
    IF remaining_days < 0 OR remaining_days > 999.
      result-RemainingDaysToFlight = 0.
    ELSE.
      result-RemainingDaysToFlight = result-FlightDate - today.
    ENDIF.

    "VE DaysToFlightIndicator: remaining days to flight *indicator*
    "(dataPoint: 1 = red | 2 = orange | 3 = green | 4 = grey | 5 = bleu)
    IF remaining_days >= 6.
      result-DaysToFlightIndicator = 3. "green
    ELSEIF remaining_days <= 5 AND remaining_days >= 3.
      result-DaysToFlightIndicator = 2. "orange
    ELSEIF remaining_days <= 2 AND remaining_days >= 0.
      result-DaysToFlightIndicator = 1. "red
    ELSE.
      result-DaysToFlightIndicator = 4. "grey
    ENDIF.

    "VE BookingStatusIndicator: booking status indicator
    "(criticality: 1 = red | 2 = orange | 3 = green)
    CASE result-BookingStatus.
      WHEN 'X'.
        result-BookingStatusIndicator = 1.
      WHEN 'N'.
        result-BookingStatusIndicator = 2.
      WHEN 'B'.
        result-BookingStatusIndicator = 3.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
