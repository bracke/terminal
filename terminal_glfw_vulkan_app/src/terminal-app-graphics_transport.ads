with Terminal.Common.Bytes;

package Terminal.App.Graphics_Transport is
   --  Local Kitty transfer media are deliberately isolated from the terminal
   --  core.  The core only parses protocol controls; this package owns the
   --  Linux filesystem/POSIX shared-memory security boundary.
   Max_Location_Length : constant := 4_096;
   Max_Transfer_Bytes  : constant := 1_024 * 1_024;

   type Access_Policy is record
      Allow_Regular_Files   : Boolean := False;
      Allow_Temporary_Files : Boolean := True;
      Allow_Shared_Memory   : Boolean := True;
   end record;

   Default_Access_Policy : constant Access_Policy := (others => <>);
   Trusted_Access_Policy : constant Access_Policy :=
     (Allow_Regular_Files   => True,
      Allow_Temporary_Files => True,
      Allow_Shared_Memory   => True);

   type Load_Status is
     (Load_Ok,
      Load_Invalid_Location,
      Load_Access_Failed,
      Load_Too_Large,
      Load_Allocation_Failed);

   type Byte_Array_Access is access Terminal.Common.Bytes.Byte_Array;

   procedure Load
     (Medium          : Character;
      Encoded_Location : String;
      Offset          : Natural;
      Size            : Natural;
      Size_Specified  : Boolean;
      Policy          : Access_Policy;
      Maximum_Bytes   : Positive;
      Bytes           : out Byte_Array_Access;
      Length          : out Natural;
      Status          : out Load_Status);

   procedure Load
     (Medium          : Character;
      Encoded_Location : String;
      Offset          : Natural;
      Size            : Natural;
      Size_Specified  : Boolean;
      Bytes           : out Byte_Array_Access;
      Length          : out Natural;
      Status          : out Load_Status);

   procedure Release (Bytes : in out Byte_Array_Access);
end Terminal.App.Graphics_Transport;
