/// Where a Gana publishes the result of one run. Exactly one of the
/// matching `outputGroupId` / `outputGroupId` / `outputDmConversationId`
/// fields on `GanaModel` is non-null per outputType (`feed` carries none).
enum GanaOutputType {
  feed,
  group,
  privateGroup,
  dm,
}
