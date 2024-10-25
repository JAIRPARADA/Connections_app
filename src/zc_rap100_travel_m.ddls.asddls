@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: '##GENERATED Travel App (DEV_100)'
@Search.searchable: true
@ObjectModel.semanticKey: ['TravelID'] //case-sensitive
define root view entity ZC_RAP100_TRAVEL_M
provider contract transactional_query
as projection on ZR_RAP100_TRAVEL_M
{
@Search.defaultSearchElement: true
@Search.fuzzinessThreshold: 0.90
key TravelID,

@Search.defaultSearchElement: true
@ObjectModel.text.element: ['AgencyName'] //case-sensitive
@Consumption.valueHelpDefinition: [{ entity : {name: '/DMO/I_Agency_StdVH', element: 'AgencyID' }, 
useForValidation: true }]
AgencyID,
_Agency.Name as AgencyName,

@Search.defaultSearchElement: true
@ObjectModel.text.element: ['CustomerName'] //case-sensitive
@Consumption.valueHelpDefinition: [{ entity : {name: '/DMO/I_Customer_StdVH', element: 'CustomerID' }, 
useForValidation: true }]
CustomerID,
_Customer.LastName as CustomerName,

BeginDate,
EndDate,
BookingFee,
TotalPrice,

@Consumption.valueHelpDefinition: [{ entity: {name: 'I_CurrencyStdVH', element: 'Currency' }, 
useForValidation: true }]
CurrencyCode,
Description,

@ObjectModel.text.element: ['OverallStatusText'] //case-sensitive
@Consumption.valueHelpDefinition: [{ entity: {name: '/DMO/I_Overall_Status_VH', element: 'OverallStatus' }, 
useForValidation: true }]
OverallStatus,
_OverallStatus._Text.Text as OverallStatusText : localized,

@ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRAPDEV_CALC_TRAV_ELEM_100'
@EndUserText.label: 'Overall Status Indicator'
virtual OverallStatusIndicator : abap.int2,

Attachment,
MimeType,
FileName,
LocalLastChangedAt,

// public associations
_Booking : redirected to composition child ZC_RAP100_BOOK_M,
_Agency,
_Customer,
_OverallStatus,
_Currency

}
