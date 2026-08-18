trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ContentDocumentLinkTriggerHandler.handle(Trigger.new);
    }
}
