@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for Booking'
@ObjectModel.semanticKey: [ 'BookingID' ]
@Search.searchable: true
define view entity ZC_RAP100_BOOK_M
  as projection on ZR_RAP100_BOOK_M
{
          @Search.defaultSearchElement: true
          @Search.fuzzinessThreshold: 0.90
  key     TravelID,

          @Search.defaultSearchElement: true
          @Search.fuzzinessThreshold: 0.90
  key     BookingID,

          BookingDate,

          @Consumption.valueHelpDefinition: [ {
          entity: {
          name: '/DMO/I_Customer_StdVH',
          element: 'CustomerID'
          },
          useForValidation: true
          } ]
          @ObjectModel.text.element: ['CustomerName'] //annotation added
          CustomerID,
          _Customer.LastName        as CustomerName, //element added

          @Consumption.valueHelpDefinition: [
          { entity: {name: '/DMO/I_Flight_StdVH', element: 'AirlineID'},
          additionalBinding: [ { localElement: 'FlightDate', element: 'FlightDate', usage: #RESULT },
          { localElement: 'ConnectionID', element: 'ConnectionID', usage: #RESULT },
          { localElement: 'FlightPrice', element: 'Price', usage: #RESULT },
          { localElement: 'CurrencyCode', element: 'CurrencyCode', usage: #RESULT } ] } ]
          @ObjectModel.text.element: ['CarrierName'] //annotation added
          CarrierID,
          _Carrier.Name             as CarrierName, //element added

          @Consumption.valueHelpDefinition: [
          { entity: { name: '/DMO/I_Flight_StdVH', element: 'ConnectionID'},
          additionalBinding: [ { localElement: 'FlightDate', element: 'FlightDate', usage: #RESULT },
          { localElement: 'CarrierID', element: 'AirlineID', usage: #FILTER_AND_RESULT },
          { localElement: 'FlightPrice', element: 'Price', usage: #RESULT },
          { localElement: 'CurrencyCode', element: 'CurrencyCode', usage: #RESULT } ] } ]
          ConnectionID,

          @Consumption.valueHelpDefinition: [
          { entity: { name: '/DMO/I_Flight_StdVH', element: 'FlightDate'},
          additionalBinding: [ { localElement: 'CarrierID', element: 'AirlineID', usage: #FILTER_AND_RESULT },
          { localElement: 'ConnectionID', element: 'ConnectionID', usage: #FILTER_AND_RESULT },
          { localElement: 'FlightPrice', element: 'Price', usage: #RESULT },
          { localElement: 'CurrencyCode', element: 'CurrencyCode', usage: #RESULT } ] } ]
          FlightDate,

          @Consumption.valueHelpDefinition: [
          { entity: { name: '/DMO/I_Flight_StdVH', element: 'Price'},
          additionalBinding: [ { localElement: 'FlightDate', element: 'FlightDate', usage: #FILTER_AND_RESULT },
          { localElement: 'CarrierID', element: 'AirlineID', usage: #FILTER_AND_RESULT },
          { localElement: 'ConnectionID', element: 'ConnectionID', usage: #FILTER_AND_RESULT },
          { localElement: 'CurrencyCode', element: 'CurrencyCode', usage: #RESULT } ] } ]
          @Semantics.amount.currencyCode: 'CurrencyCode'
          FlightPrice,

          @Consumption.valueHelpDefinition: [ {
          entity: {
          name: 'I_CurrencyStdVH',
          element: 'Currency'
          },
          useForValidation: true
          } ]
          CurrencyCode,

          @Consumption.valueHelpDefinition: [ {
          entity: {
          name: '/DMO/I_Booking_Status_VH',
          element: 'BookingStatus'
          },
          useForValidation: true
          } ]
          @ObjectModel.text.element: ['BookingStatusText'] //annotation added
          BookingStatus,
          _BookingStatus._Text.Text as BookingStatusText : localized, //element added

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRAPDEV_CALC_BOOK_ELEM_100'
          @EndUserText.label: 'Booking Status Indicator'
  virtual BookingStatusIndicator : abap.int1,

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRAPDEV_CALC_BOOK_ELEM_100'
          @EndUserText.label: 'Initial Days to Flight'
  virtual InitialDaysToFlight    : abap.int1,

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRAPDEV_CALC_BOOK_ELEM_100'
          @EndUserText.label: 'Remaining Days to Flight'
  virtual RemainingDaysToFlight  : abap.int1,

          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRAPDEV_CALC_BOOK_ELEM_100'
          @EndUserText.label: 'Days to Flight Indicator'
  virtual DaysToFlightIndicator  : abap.int1,

          LocalLastChangedAt,


          // public associations
          _Travel : redirected to parent ZC_RAP100_TRAVEL_M,
          _Customer,
          _Carrier,
          _Connection,
          _Flight,
          _BookingStatus,
          _Currency

}
