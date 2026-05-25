abstract class ChannelThreadEvent {
  const ChannelThreadEvent();
}

class LoadChannelThreadEvent extends ChannelThreadEvent {
  const LoadChannelThreadEvent(this.messageId);
  final String messageId;
}

class SaveChannelMessageEvent extends ChannelThreadEvent {
  const SaveChannelMessageEvent(this.messageId);
  final String messageId;
}

class UnsaveChannelMessageEvent extends ChannelThreadEvent {
  const UnsaveChannelMessageEvent(this.messageId);
  final String messageId;
}
