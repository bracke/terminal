with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.Common.Bytes;

package body Terminal.App.Frame_Image_Storage is
   use type RM.Image_Data_Access;
   use type RM.Image_Array_Access;
   procedure Free_Images is new Ada.Unchecked_Deallocation
     (RM.Image_Array, RM.Image_Array_Access);
   procedure Free_Owners is new Ada.Unchecked_Deallocation
     (Buffer_Ownership_Array, Buffer_Ownership_Array_Access);
   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, RM.Image_Data_Access);

   function Grown_Capacity
     (Current  : Natural;
      Required : Positive) return Positive is
   begin
      if Current >= Required then
         return Positive (Current);
      elsif Current = 0 then
         return Required;
      elsif Current <= Natural'Last / 2 then
         return Positive'Max (Required, Positive (Current * 2));
      else
         return Required;
      end if;
   end Grown_Capacity;

   procedure Release_Buffers (Owner : in out Buffer_Ownership) is
      Decoded : RM.Image_Data_Access := Owner.Decoded;
      Encoded : RM.Image_Data_Access := Owner.Encoded;
      Preview : RM.Image_Data_Access := Owner.Preview;
      Encoded_Aliases_Decoded : constant Boolean := Encoded = Decoded;
      Preview_Aliases_Decoded : constant Boolean := Preview = Decoded;
      Preview_Aliases_Encoded : constant Boolean := Preview = Encoded;
   begin
      Owner := (others => null);
      if Decoded /= null then
         Free_Image_Data (Decoded);
      end if;
      if Encoded /= null and then not Encoded_Aliases_Decoded then
         Free_Image_Data (Encoded);
      end if;
      if Preview /= null
        and then not Preview_Aliases_Decoded
        and then not Preview_Aliases_Encoded
      then
         Free_Image_Data (Preview);
      end if;
   end Release_Buffers;

   procedure Ensure_Capacity
     (S        : in out Storage;
      Required : Positive;
      Success  : out Boolean)
   is
      Replacement : RM.Image_Array_Access := null;
      Owner_Replacement : Buffer_Ownership_Array_Access := null;
      New_Capacity : Positive;
   begin
      Success := True;
      if Capacity (S) >= Required then
         return;
      end if;
      New_Capacity := Grown_Capacity (Capacity (S), Required);
      Replacement := new RM.Image_Array (1 .. New_Capacity);
      Owner_Replacement := new Buffer_Ownership_Array'(1 .. New_Capacity => <>);
      if S.Items /= null and then S.Length > 0 then
         Replacement (1 .. S.Length) := S.Items (1 .. S.Length);
         Owner_Replacement (1 .. S.Length) := S.Owners (1 .. S.Length);
      end if;
      Free_Images (S.Items);
      Free_Owners (S.Owners);
      S.Items := Replacement;
      S.Owners := Owner_Replacement;
   exception
      when Storage_Error =>
         Free_Images (Replacement);
         Free_Owners (Owner_Replacement);
         Success := False;
   end Ensure_Capacity;

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command) is
      Decoded : RM.Image_Data_Access := null;
      Encoded : RM.Image_Data_Access := null;
      Preview : RM.Image_Data_Access := null;
   begin
      Append (S, Command, Decoded, Encoded, Preview);
   end Append;

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command;
      Decoded : in out RM.Image_Data_Access;
      Encoded : in out RM.Image_Data_Access;
      Preview : in out RM.Image_Data_Access) is
      Index : Positive;

      function Already_Owned (Data : RM.Image_Data_Access) return Boolean is
      begin
         if Data = null then
            return False;
         end if;
         for I in 1 .. S.Length loop
            if Data = S.Owners (I).Decoded
              or else Data = S.Owners (I).Encoded
              or else Data = S.Owners (I).Preview
            then
               return True;
            end if;
         end loop;
         return False;
      end Already_Owned;
   begin
      if Is_Full (S) then
         raise Program_Error with "frame image storage capacity exhausted";
      elsif Already_Owned (Decoded)
        or else Already_Owned (Encoded)
        or else Already_Owned (Preview)
      then
         raise Program_Error with
           "frame image buffer is already owned by another command";
      end if;
      Index := S.Length + 1;
      S.Items (Index) := Command;
      S.Owners (Index) :=
        (Decoded => Decoded, Encoded => Encoded, Preview => Preview);
      S.Length := Index;
      Decoded := null;
      Encoded := null;
      Preview := null;
   end Append;

   procedure Truncate (S : in out Storage; New_Count : Natural) is
   begin
      if New_Count > S.Length then
         raise Constraint_Error with "cannot grow frame image storage by truncating";
      end if;
      if New_Count < S.Length then
         for I in Positive (New_Count + 1) .. S.Length loop
            Release_Buffers (S.Owners (I));
            S.Items (I) := (others => <>);
         end loop;
      end if;
      S.Length := New_Count;
   end Truncate;

   procedure Reset (S : in out Storage) is
   begin
      Truncate (S, 0);
   end Reset;

   procedure Release (S : in out Storage) is
   begin
      Reset (S);
      Free_Images (S.Items);
      Free_Owners (S.Owners);
   end Release;

   overriding procedure Finalize (S : in out Storage) is
   begin
      Release (S);
   exception
      when others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage);
   end Finalize;

   function Count (S : Storage) return Natural is (S.Length);

   function Capacity (S : Storage) return Natural is
     (if S.Items = null then 0 else S.Items'Length);

   function Is_Full (S : Storage) return Boolean is
     (S.Items = null or else S.Owners = null or else S.Length >= Capacity (S));

   function Commands (S : Storage) return RM.Image_Array_View is
     (RM.Image_Array_View (S.Items));

   function Element
     (S     : Storage;
      Index : Positive) return RM.Image_Command
   is
   begin
      if Index > S.Length then
         raise Constraint_Error with "frame image command index out of bounds";
      end if;
      return S.Items (Index);
   end Element;
end Terminal.App.Frame_Image_Storage;
