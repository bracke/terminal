package body Terminal.App.Graphics_Transport.Testing is
   function Reject_Unlink (Name : String) return Boolean is
      pragma Unreferenced (Name);
   begin
      return False;
   end Reject_Unlink;

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
      Status           : out Load_Status)
   is
   begin
      Load_With_Unlinker
        (Medium,
         Encoded_Location,
         Offset,
         Size,
         Size_Specified,
         Policy,
         Maximum_Bytes,
         Bytes,
         Length,
         Status,
         Reject_Unlink'Access);
   end Load_With_Shared_Memory_Unlink_Failure;
end Terminal.App.Graphics_Transport.Testing;
