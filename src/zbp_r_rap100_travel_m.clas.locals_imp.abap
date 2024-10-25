CLASS lhc_zr_rap100_travel_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        accepted TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected TYPE c LENGTH 1 VALUE 'X', "Rejected
      END OF travel_status.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Travel
        RESULT result,
      earlynumbering_create FOR NUMBERING
        IMPORTING entities FOR CREATE Travel,
      setStatusToOpen FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Travel~setStatusToOpen,
      validateCustomer FOR VALIDATE ON SAVE
        IMPORTING keys FOR Travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.
    METHODS copyTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~copyTravel.

    METHODS deductDiscount FOR MODIFY
      IMPORTING keys FOR ACTION Travel~deductDiscount RESULT result.
    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.
    METHODS recalcTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~recalcTotalPrice.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~calculateTotalPrice.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

ENDCLASS.

CLASS lhc_zr_rap100_travel_m IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD earlynumbering_create.
    DATA:
      entity             TYPE STRUCTURE FOR CREATE zr_rap100_travel_m,
      travel_id_max      TYPE /dmo/travel_id,
      max_travelid_draft TYPE /dmo/travel_id,
      " change to abap_false if you get the ABAP Runtime error 'BEHAVIOR_ILLEGAL_STATEMENT'
      use_number_range   TYPE abap_bool VALUE abap_false.

    "Ensure Travel ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    LOOP AT entities INTO entity WHERE TravelID IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-travel.
    ENDLOOP.

    DATA(entities_wo_travelid) = entities.
    "Remove the entries with an existing Travel ID
    DELETE entities_wo_travelid WHERE TravelID IS NOT INITIAL.

    IF use_number_range = abap_true.
      "Get numbers
      TRY.
          cl_numberrange_runtime=>number_get(
          EXPORTING
          nr_range_nr = '01'
          object = '/DMO/TRV_M'
          quantity = CONV #( lines( entities_wo_travelid ) )
          IMPORTING
          number = DATA(number_range_key)
          returncode = DATA(number_range_return_code)
          returned_quantity = DATA(number_range_returned_quantity)
          ).
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          LOOP AT entities_wo_travelid INTO entity.
            APPEND VALUE #( %cid = entity-%cid
            %key = entity-%key
            %is_draft = entity-%is_draft
            %msg = lx_number_ranges
            ) TO reported-travel.
            APPEND VALUE #( %cid = entity-%cid
            %key = entity-%key
            %is_draft = entity-%is_draft
            ) TO failed-travel.
          ENDLOOP.
          EXIT.
      ENDTRY.

      "determine the first free travel ID from the number range
      travel_id_max = number_range_key - number_range_returned_quantity.
    ELSE.
      "determine the first free travel ID without number range
      "Get max travel ID from active table
      SELECT SINGLE FROM zrap100_travel_m FIELDS MAX( travel_id ) AS travelID INTO @travel_id_max.
      "Get max travel ID from draft table
      SELECT SINGLE FROM zrap100_travel_d FIELDS MAX( travelid ) INTO @max_travelid_draft.
      IF max_travelid_draft > travel_id_max.
        travel_id_max = max_travelid_draft.
      ENDIF.
    ENDIF.

    "Set Travel ID for new instances w/o ID
    LOOP AT entities_wo_travelid INTO entity.
      travel_id_max += 1.
      entity-TravelID = travel_id_max.

      APPEND VALUE #( %cid = entity-%cid
      %key = entity-%key
      %is_draft = entity-%is_draft
      ) TO mapped-travel.
    ENDLOOP.
  ENDMETHOD.

  METHOD setStatusToOpen.
    "Read travel instances of the transferred keys
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    FIELDS ( OverallStatus )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels)
    FAILED DATA(read_failed).

    "If overall travel status is already set, do nothing, i.e. remove such instances
    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    "else set overall travel status to open ('O')
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR travel IN travels ( %tky = travel-%tky
    OverallStatus = travel_status-open ) )
    REPORTED DATA(update_reported).

    "Set the changing parameter
    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.

**********************************************************************
* Validation: Check the validity of the entered customer data
**********************************************************************
  METHOD validateCustomer.
    "read relevant travel instance data
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    FIELDS ( CustomerID )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    "optimization of DB select: extract distinct non-initial customer IDs
    customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = customerID EXCEPT * ).
    DELETE customers WHERE customer_id IS INITIAL.
    IF customers IS NOT INITIAL.

      "check if customer ID exists
      SELECT FROM /dmo/customer FIELDS customer_id
      FOR ALL ENTRIES IN @customers
      WHERE customer_id = @customers-customer_id
      INTO TABLE @DATA(valid_customers).
    ENDIF.

    "raise msg for non existing and initial customer id
    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #( %tky = travel-%tky
      %state_area = 'VALIDATE_CUSTOMER'
      ) TO reported-travel.

      IF travel-CustomerID IS INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_CUSTOMER'
        %msg = NEW /dmo/cm_flight_messages(
        textid = /dmo/cm_flight_messages=>enter_customer_id
        severity = if_abap_behv_message=>severity-error )
        %element-CustomerID = if_abap_behv=>mk-on
        ) TO reported-travel.

      ELSEIF travel-CustomerID IS NOT INITIAL AND NOT line_exists( valid_customers[ customer_id = travel-CustomerID ] ).
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_CUSTOMER'
        %msg = NEW /dmo/cm_flight_messages(
        customer_id = travel-customerid
        textid = /dmo/cm_flight_messages=>customer_unkown
        severity = if_abap_behv_message=>severity-error )
        %element-CustomerID = if_abap_behv=>mk-on
        ) TO reported-travel.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

**********************************************************************
* Validation: Check the validity of begin and end dates
**********************************************************************
  METHOD validateDates.

    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    FIELDS ( BeginDate EndDate TravelID )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #( %tky = travel-%tky
      %state_area = 'VALIDATE_DATES' ) TO reported-travel.

      IF travel-BeginDate IS INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_DATES'
        %msg = NEW /dmo/cm_flight_messages(
        textid = /dmo/cm_flight_messages=>enter_begin_date
        severity = if_abap_behv_message=>severity-error )
        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel-BeginDate < cl_abap_context_info=>get_system_date( ) AND travel-BeginDate IS NOT INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_DATES'
        %msg = NEW /dmo/cm_flight_messages(
        begin_date = travel-BeginDate
        textid = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
        severity = if_abap_behv_message=>severity-error )
        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel-EndDate IS INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_DATES'
        %msg = NEW /dmo/cm_flight_messages(
        textid = /dmo/cm_flight_messages=>enter_end_date
        severity = if_abap_behv_message=>severity-error )
        %element-EndDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel-EndDate < travel-BeginDate AND travel-BeginDate IS NOT INITIAL
      AND travel-EndDate IS NOT INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel-%tky
        %state_area = 'VALIDATE_DATES'
        %msg = NEW /dmo/cm_flight_messages(
        textid = /dmo/cm_flight_messages=>begin_date_bef_end_date
        begin_date = travel-BeginDate
        end_date = travel-EndDate
        severity = if_abap_behv_message=>severity-error )
        %element-BeginDate = if_abap_behv=>mk-on
        %element-EndDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

**************************************************************************
* Instance-bound non-factory action:
* Deduct the specified discount from the booking fee (BookingFee)
**************************************************************************
  METHOD deductDiscount.
    DATA travels_for_update TYPE TABLE FOR UPDATE zr_rap100_travel_m.
    DATA(keys_with_valid_discount) = keys.

    " read relevant travel instance data (only booking fee)
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    FIELDS ( BookingFee )
    WITH CORRESPONDING #( keys_with_valid_discount )
    RESULT DATA(travels).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      DATA percentage TYPE decfloat16.
      DATA(discount_percent) = keys_with_valid_discount[ KEY draft %tky = <travel>-%tky ]-%param-discount_percent.
      percentage = discount_percent / 100 .
      DATA(reduced_fee) = <travel>-BookingFee * ( 1 - 3 / 10 ) .

      APPEND VALUE #( %tky = <travel>-%tky
      BookingFee = reduced_fee
      ) TO travels_for_update.
    ENDLOOP.

    " update data with reduced fee
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( BookingFee )
    WITH travels_for_update.

    " read changed data for action result
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    ALL FIELDS WITH
    CORRESPONDING #( travels )
    RESULT DATA(travels_with_discount).

    " set action result
    result = VALUE #( FOR travel IN travels_with_discount ( %tky = travel-%tky
    %param = travel ) ).
  ENDMETHOD.

**************************************************************************
* Instance-bound factory action `copyTravel`:
* Copy an existing travel instance
**************************************************************************
  METHOD copyTravel.
    DATA:
    travels TYPE TABLE FOR CREATE zr_rap100_travel_m\\travel.

    " remove travel instances with initial %cid (i.e., not set by caller API)
    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_inital_cid).
    ASSERT key_with_inital_cid IS INITIAL.

    " read the data from the travel instances to be copied
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travel_read_result)
    FAILED failed.

    LOOP AT travel_read_result ASSIGNING FIELD-SYMBOL(<travel>).
      " fill in travel container for creating new travel instance
      APPEND VALUE #( %cid = keys[ KEY entity %key = <travel>-%key ]-%cid
      %is_draft = keys[ KEY entity %key = <travel>-%key ]-%param-%is_draft
      %data = CORRESPONDING #( <travel> EXCEPT TravelID )
      )
      TO travels ASSIGNING FIELD-SYMBOL(<new_travel>).

      " adjust the copied travel instance data
      "" BeginDate must be on or after system date
      <new_travel>-BeginDate = cl_abap_context_info=>get_system_date( ).
      "" EndDate must be after BeginDate
      <new_travel>-EndDate = cl_abap_context_info=>get_system_date( ) + 30.
      "" OverallStatus of new instances must be set to open ('O')
      <new_travel>-OverallStatus = travel_status-open.
    ENDLOOP.

    " create new BO instance
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY travel
    CREATE FIELDS ( AgencyID CustomerID BeginDate EndDate BookingFee
    TotalPrice CurrencyCode OverallStatus Description )
    WITH travels
    MAPPED DATA(mapped_create).

    " set the new BO instances
    mapped-travel = mapped_create-travel .
  ENDMETHOD.

*************************************************************************************
* Instance-bound non-factory action: Set the overall travel status to 'A' (accepted)
*************************************************************************************
  METHOD acceptTravel.
    " modify travel instance
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys ( %tky = key-%tky
    OverallStatus = travel_status-accepted ) ) " 'A'
    FAILED failed
    REPORTED reported.

    " read changed data for action result
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    ALL FIELDS WITH
    CORRESPONDING #( keys )
    RESULT DATA(travels).

    " set the action result parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
    %param = travel ) ).
  ENDMETHOD.

*************************************************************************************
* Instance-bound non-factory action: Set the overall travel status to 'X' (rejected)
*************************************************************************************
  METHOD rejectTravel.
    " modify travel instance(s)
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys ( %tky = key-%tky
    OverallStatus = travel_status-rejected ) ) " 'X'
    FAILED failed
    REPORTED reported.

    " read changed data for action result
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    ALL FIELDS WITH
    CORRESPONDING #( keys )
    RESULT DATA(travels).

    " set the action result parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
    %param = travel ) ).
  ENDMETHOD.

**************************************************************************
* Internal instance-bound action calculateTotalPrice
**************************************************************************
  METHOD reCalctotalprice.
    TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: amounts_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    " Read all relevant travel instances.
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    FIELDS ( BookingFee CurrencyCode )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DELETE travels WHERE CurrencyCode IS INITIAL.

    " Read all associated bookings and add them to the total price.
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel BY \_Booking
    FIELDS ( FlightPrice CurrencyCode )
    WITH CORRESPONDING #( travels )
    LINK DATA(booking_links)
    RESULT DATA(bookings).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      " Set the start for the calculation by adding the booking fee.
      amounts_per_currencycode = VALUE #( ( amount = <travel>-bookingfee
      currency_code = <travel>-currencycode ) ).

      LOOP AT booking_links INTO DATA(booking_link) USING KEY id WHERE source-%tky = <travel>-%tky.
        " Short dump occurs if link table does not match read table, which must never happen
        DATA(booking) = bookings[ KEY id %tky = booking_link-target-%tky ].
        COLLECT VALUE ty_amount_per_currencycode( amount = booking-flightprice
        currency_code = booking-currencycode ) INTO amounts_per_currencycode.
      ENDLOOP.

      DELETE amounts_per_currencycode WHERE currency_code IS INITIAL.

      CLEAR <travel>-TotalPrice.
      LOOP AT amounts_per_currencycode INTO DATA(amount_per_currencycode).
        " If needed do a Currency Conversion
        IF amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += amount_per_currencycode-amount.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
          EXPORTING
          iv_amount = amount_per_currencycode-amount
          iv_currency_code_source = amount_per_currencycode-currency_code
          iv_currency_code_target = <travel>-CurrencyCode
          iv_exchange_rate_date = cl_abap_context_info=>get_system_date( )
          IMPORTING
          ev_amount = DATA(total_booking_price_per_curr)
          ).
          <travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " write back the modified total_price of travels
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( TotalPrice )
    WITH CORRESPONDING #( travels ).

  ENDMETHOD.

**************************************************************************
* determination calculateTotalPrice
**************************************************************************
  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY Travel
    EXECUTE reCalcTotalPrice
    FROM CORRESPONDING #( keys ).

  ENDMETHOD.

**************************************************************************
* Instance-bound dynamic feature control
**************************************************************************
  METHOD get_instance_features.
    " read relevant travel instance data
    READ ENTITIES OF zr_rap100_travel_m IN LOCAL MODE
    ENTITY travel
    FIELDS ( TravelID OverallStatus )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels)
    FAILED failed.

    " evaluate the conditions, set the operation state, and set result parameter
    result = VALUE #( FOR travel IN travels
    ( %tky = travel-%tky

    %features-%update = COND #( WHEN travel-OverallStatus = travel_status-accepted
    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )

    %features-%delete = COND #( WHEN travel-OverallStatus = travel_status-open
    THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

    %action-Edit = COND #( WHEN travel-OverallStatus = travel_status-accepted
    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )

    %action-acceptTravel = COND #( WHEN travel-OverallStatus = travel_status-accepted
    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )

    %action-rejectTravel = COND #( WHEN travel-OverallStatus = travel_status-rejected
    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
    ) ).
  ENDMETHOD.

ENDCLASS.
