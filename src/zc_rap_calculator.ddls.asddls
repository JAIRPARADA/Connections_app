@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
define root view entity ZC_RAP_CALCULATOR
  provider contract TRANSACTIONAL_QUERY
  as projection on ZR_RAP_CALCULATOR
{
  key CalcUuid,
  OperandA,
  OperandB,
  Operator,
  CalcResult,
  CreatedAt,
  CreatedBy,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt
  
}
