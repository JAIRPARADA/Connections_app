@EndUserText.label: 'Abstract entity for Days To Flight'
define abstract entity ZA_RAP100_DaysToFlight_M
{
  initial_days_to_flight   : abap.int4;
  remaining_days_to_flight : abap.int4;
  booking_status_indicator : abap.int4;
  days_to_flight_indicator : abap.int4;
}
