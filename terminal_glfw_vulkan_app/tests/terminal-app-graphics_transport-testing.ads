package Terminal.App.Graphics_Transport.Testing is
   procedure Load_With_Shared_Memory_Unlink_Failure
     (Medium           : Character;
      Encoded_Location : String;
      Offset           : Natural;
      Size             : Natural;
      Size_Specified   : Boolean;
      Policy           : Access_Policy;
      Maximum_Bytes    : Positive;
      Bytes            : out Byte_Array_Access;
      Length           : out Natural;
      Status           : out Load_Status);
end Terminal.App.Graphics_Transport.Testing;
