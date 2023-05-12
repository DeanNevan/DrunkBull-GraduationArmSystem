import minipb

### Encode/Decode a Message with schema defined via Fields
@minipb.process_message_fields
class HelloWorldMessage(minipb.Message):
    msg = minipb.Field(1, minipb.TYPE_STRING)

# Creating a Message instance
#   Method 1: init with kwargs work!
msg_obj = HelloWorldMessage(msg='Hello world!')

#   Method 2: from_dict, iterates over all Field's declared in order on the class
msg_obj = HelloWorldMessage.from_dict({'msg': 'Hello world!'})

# Encode a message
encoded_msg = msg_obj.encode()
# encoded_message == b'\n\x0cHello world!'

# Decode a message
decoded_msg_obj = HelloWorldMessage.decode(encoded_msg)
# decoded_msg == HelloWorldMessage(msg='Hello world!')

decoded_dict = decoded_msg_obj.to_dict()
# decoded_dict == {'msg': 'Hello world!'}

print(decoded_dict)