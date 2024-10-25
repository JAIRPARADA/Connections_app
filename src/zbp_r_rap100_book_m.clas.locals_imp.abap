CLASS lhc_booking DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateTotalPrice.
    METHODS getDaysToFlight FOR READ
      IMPORTING keys FOR FUNCTION Booking~getDaysToFlight RESULT result.

ENDCLASS.

CLASS lhc_booking IMPLEMENTATION.

**************************************************************************
* Determination calculateTotalPrice
**************************************************************************
  METHOD calculateTotalPrice.
    " Read all parent IDs
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Booking BY \_Travel
    FIELDS ( TravelID )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    " Trigger Re-Calculation on Root Node
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    EXECUTE reCalcTotalPrice
    FROM CORRESPONDING #( travels ).
  ENDMETHOD.

**************************************************************************
* Instance-bound function for calculating virtual elements via EML calls
**************************************************************************
  METHOD getDaysToFlight.
    DATA:
      c_booking_entity TYPE zc_rap100_book_m,
      bookings_result  TYPE TABLE FOR FUNCTION RESULT ZR_RAP100_TRAVEL_M\\Booking~getdaystoflight,
      booking_result   LIKE LINE OF bookings_result.

    "read relevant data
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY booking
    FIELDS ( TravelID BookingStatus BookingID FlightDate BookingDate )
* ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(bookings).

    LOOP AT bookings ASSIGNING FIELD-SYMBOL(<booking>).
      c_booking_entity = CORRESPONDING #( <booking> ).
      "set relevant transfered data
      booking_result = CORRESPONDING #( <booking> ).
      "calculate virtual elements
      booking_result-%param
      = CORRESPONDING #( zrapdev_calc_book_elem_100=>calculate_days_to_flight( c_booking_entity )
      MAPPING booking_status_indicator = BookingStatusIndicator
      days_to_flight_indicator = DaysToFlightIndicator
      initial_days_to_flight = InitialDaysToFlight
      remaining_days_to_flight = RemainingDaysToFlight ).
      "append
      APPEND booking_result TO bookings_result.
    ENDLOOP.

    result = bookings_result.

  ENDMETHOD.

ENDCLASS.
