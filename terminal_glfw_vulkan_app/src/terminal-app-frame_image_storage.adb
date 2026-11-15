with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Store.Frame_Borrows;
with Terminal.App.Owned_Image_Data;
with Terminal.Common.Bytes;

package body Terminal.App.Frame_Image_Storage is
   use type RM.Image_Data_View;
   use type RM.Image_Array_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Frame_Arena_Access;
   procedure Free_Images is new Ada.Unchecked_Deallocation
     (RM.Image_Array, RM.Image_Array_Access);
   procedure Free_Arena is new Ada.Unchecked_Deallocation
     (Frame_Arena, Frame_Arena_Access);

   procedure Release_Arena (Item : in out Frame_Arena_Access) is
   begin
      if Item /= null then
         Free_Images (Item.Published);
         Free_Arena (Item);
      end if;
   end Release_Arena;

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
   begin
      Terminal.App.Image_Store.Frame_Borrows.Release (Owner.Borrow);
      Terminal.App.Owned_Image_Data.Release (Owner.Decoded);
      Terminal.App.Owned_Image_Data.Release (Owner.Encoded);
      Terminal.App.Owned_Image_Data.Release (Owner.Preview);
   end Release_Buffers;

   function Command_Description_Valid
     (Command : RM.Image_Command) return Boolean is
      Decoded_View_Length : constant Natural :=
        (if Command.Decoded_Bytes = null
         then 0 else Command.Decoded_Bytes'Length);
      Encoded_View_Length : constant Natural :=
        (if Command.Encoded_Source_Bytes = null
         then 0 else Command.Encoded_Source_Bytes'Length);
      Preview_View_Length : constant Natural :=
        (if Command.Decoded_Preview_Bytes = null
         then 0 else Command.Decoded_Preview_Bytes'Length);
      Decoded_Valid : constant Boolean :=
        (case Command.Decoded_Source is
            when RM.Image_Decoded_Source_None =>
              --  Placeholder diagnostics may retain the logical decoded
              --  extent even though no random-access decoded source exists.
              Command.Decoded_Bytes = null,
            when RM.Image_Decoded_Source_Buffer =>
              Command.Decoded_Bytes /= null
              and then Command.Decoded_Byte_Length > 0
              and then Command.Decoded_Byte_Length <= Decoded_View_Length,
            when RM.Image_Decoded_Source_Raw_Base64
               | RM.Image_Decoded_Source_PNG_Base64
               | RM.Image_Decoded_Source_Sixel_Text =>
              Command.Decoded_Bytes = null
              and then Command.Decoded_Byte_Length > 0
              and then Command.Encoded_Source_Bytes /= null);
      Encoded_Valid : constant Boolean :=
        (if Command.Encoded_Source_Bytes = null
         then Command.Encoded_Source_Length = 0
         else Command.Encoded_Source_Length > 0
           and then Command.Encoded_Source_Length <= Encoded_View_Length);
      Preview_Valid : constant Boolean :=
        (if Command.Decoded_Preview_Bytes = null
         then Command.Decoded_Preview_Length = 0
         else Command.Decoded_Preview_Length > 0
           and then Command.Decoded_Preview_Length <= Preview_View_Length
           and then Command.Decoded_Preview_Length <=
             RM.Max_Image_Decoded_Preview_Length);
   begin
      return Decoded_Valid and then Encoded_Valid and then Preview_Valid;
   end Command_Description_Valid;

   procedure Ensure_Capacity
     (S        : in out Storage;
      Required : Positive;
      Success  : out Boolean)
   is
      Replacement : Frame_Arena_Access := null;
      New_Capacity : Positive;
   begin
      Success := True;
      if Capacity (S) >= Required then
         return;
      end if;
      New_Capacity := Grown_Capacity (Capacity (S), Required);
      Replacement := new Frame_Arena (New_Capacity);
      Replacement.Published := new RM.Image_Array (1 .. New_Capacity);
      if S.Arena /= null and then S.Length > 0 then
         for I in 1 .. S.Length loop
            Replacement.Published (I) := S.Arena.Published (I);
            Terminal.App.Owned_Image_Data.Move
              (S.Arena.Slots (I).Owner.Decoded,
               Replacement.Slots (I).Owner.Decoded);
            Terminal.App.Owned_Image_Data.Move
              (S.Arena.Slots (I).Owner.Encoded,
               Replacement.Slots (I).Owner.Encoded);
            Terminal.App.Owned_Image_Data.Move
              (S.Arena.Slots (I).Owner.Preview,
               Replacement.Slots (I).Owner.Preview);
            Terminal.App.Image_Store.Frame_Borrows.Move
              (Source => S.Arena.Slots (I).Owner.Borrow,
               Target => Replacement.Slots (I).Owner.Borrow);
         end loop;
      end if;
      Release_Arena (S.Arena);
      S.Arena := Replacement;
   exception
      when Storage_Error =>
         Release_Arena (Replacement);
         Success := False;
   end Ensure_Capacity;

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command) is
      Decoded : Terminal.App.Owned_Image_Data.Owner;
      Encoded : Terminal.App.Owned_Image_Data.Owner;
      Preview : Terminal.App.Owned_Image_Data.Owner;
   begin
      Append (S, Command, Decoded, Encoded, Preview);
   end Append;

   procedure Append_Borrowed_Frame
     (S                : in out Storage;
      Command          : RM.Image_Command;
      Borrowed_Object  : not null Terminal.App.Image_Store.Image_Object_Access;
      Frame_Number     : Positive;
      Use_As_Decoded   : Boolean := True;
      Use_As_Preview   : Boolean := True)
   is
      Index    : Positive;
      Prepared : RM.Image_Command := Command;
      View     : RM.Image_Data_View;
      Acquired : Boolean := False;
   begin
      if Is_Full (S) then
         raise Program_Error with "frame image storage capacity exhausted";
      elsif Command.Decoded_Bytes /= null
        or else Command.Encoded_Source_Bytes /= null
        or else Command.Decoded_Preview_Bytes /= null
      then
         raise Program_Error with
           "borrowed frame command contains an external byte view";
      elsif not Use_As_Decoded and then not Use_As_Preview then
         raise Program_Error with "borrowed frame command has no byte consumer";
      end if;

      Index := S.Length + 1;
      Terminal.App.Image_Store.Frame_Borrows.Acquire_Frame
        (S.Arena.Slots (Index).Owner.Borrow,
         Borrowed_Object,
         Frame_Number,
         View);
      Acquired := View /= null;
      if View = null then
         raise Program_Error with "borrowed image frame is not available";
      end if;
      if Use_As_Decoded then
         Prepared.Decoded_Bytes := View;
         Prepared.Decoded_Byte_Length := View'Length;
         Prepared.Decoded_Source := RM.Image_Decoded_Source_Buffer;
      else
         Prepared.Decoded_Byte_Length := 0;
         Prepared.Decoded_Source := RM.Image_Decoded_Source_None;
      end if;
      if Use_As_Preview then
         Prepared.Decoded_Preview_Bytes := View;
         Prepared.Decoded_Preview_Length :=
           Natural'Min (View'Length, RM.Max_Image_Decoded_Preview_Length);
      else
         Prepared.Decoded_Preview_Length := 0;
      end if;
      Prepared.Encoded_Source_Length := 0;
      if not Command_Description_Valid (Prepared) then
         raise Program_Error with
           "borrowed frame command has an inconsistent byte description";
      end if;
      S.Arena.Published (Index) := Prepared;
      S.Length := Index;
   exception
      when others =>
         if Acquired and then S.Arena /= null then
            Terminal.App.Image_Store.Frame_Borrows.Release
              (S.Arena.Slots (Index).Owner.Borrow);
         end if;
         raise;
   end Append_Borrowed_Frame;

   procedure Append
     (S       : in out Storage;
      Command : RM.Image_Command;
      Decoded : in out Terminal.App.Owned_Image_Data.Owner;
      Encoded : in out Terminal.App.Owned_Image_Data.Owner;
      Preview : in out Terminal.App.Owned_Image_Data.Owner) is
      Index : Positive;

      function Already_Owned
        (Data : Terminal.App.Owned_Image_Data.Owner) return Boolean is
         View : constant RM.Image_Data_View :=
           Terminal.App.Owned_Image_Data.Unsafe_View (Data);
      begin
         if View = null then
            return False;
         end if;
         for I in 1 .. S.Length loop
            if Terminal.App.Owned_Image_Data.Owns
                 (S.Arena.Slots (I).Owner.Decoded, View)
              or else Terminal.App.Owned_Image_Data.Owns
                 (S.Arena.Slots (I).Owner.Encoded, View)
              or else Terminal.App.Owned_Image_Data.Owns
                 (S.Arena.Slots (I).Owner.Preview, View)
            then
               return True;
            end if;
         end loop;
         return False;
      end Already_Owned;

      function Backed_By_Transferred_Owner
        (View : RM.Image_Data_View) return Boolean is
      begin
         if View = null then
            return True;
         end if;
         return
           Terminal.App.Owned_Image_Data.Owns (Decoded, View)
           or else Terminal.App.Owned_Image_Data.Owns (Encoded, View)
           or else Terminal.App.Owned_Image_Data.Owns (Preview, View);
      end Backed_By_Transferred_Owner;

      procedure Transfer_If_Referenced
        (Source : in out Terminal.App.Owned_Image_Data.Owner;
         Target : in out Terminal.App.Owned_Image_Data.Owner) is
      begin
         if Terminal.App.Owned_Image_Data.Owns
              (Source, Command.Decoded_Bytes)
           or else Terminal.App.Owned_Image_Data.Owns
              (Source, Command.Encoded_Source_Bytes)
           or else Terminal.App.Owned_Image_Data.Owns
              (Source, Command.Decoded_Preview_Bytes)
         then
            Terminal.App.Owned_Image_Data.Move (Source, Target);
         else
            Terminal.App.Owned_Image_Data.Release (Source);
         end if;
      end Transfer_If_Referenced;

   begin
      if Is_Full (S) then
         raise Program_Error with "frame image storage capacity exhausted";
      elsif Already_Owned (Decoded)
        or else Already_Owned (Encoded)
        or else Already_Owned (Preview)
      then
         raise Program_Error with
           "frame image buffer is already owned by another command";
      elsif not Backed_By_Transferred_Owner (Command.Decoded_Bytes)
        or else not Backed_By_Transferred_Owner (Command.Encoded_Source_Bytes)
        or else not Backed_By_Transferred_Owner (Command.Decoded_Preview_Bytes)
      then
         raise Program_Error with
           "frame image command contains an unowned byte view";
      elsif not Command_Description_Valid (Command) then
         raise Program_Error with
           "frame image command has an inconsistent byte description";
      end if;
      Index := S.Length + 1;
      Transfer_If_Referenced
        (Decoded, S.Arena.Slots (Index).Owner.Decoded);
      Transfer_If_Referenced
        (Encoded, S.Arena.Slots (Index).Owner.Encoded);
      Transfer_If_Referenced
        (Preview, S.Arena.Slots (Index).Owner.Preview);
      S.Arena.Published (Index) := Command;
      S.Length := Index;
   end Append;

   procedure Truncate (S : in out Storage; New_Count : Natural) is
   begin
      if New_Count > S.Length then
         raise Constraint_Error with "cannot grow frame image storage by truncating";
      end if;
      if New_Count < S.Length then
         for I in Positive (New_Count + 1) .. S.Length loop
            Release_Buffers (S.Arena.Slots (I).Owner);
            S.Arena.Published (I) := (others => <>);
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
      Release_Arena (S.Arena);
   end Release;

   overriding procedure Finalize (S : in out Storage) is
   begin
      Release (S);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage,
            E,
            "finalize frame image storage");
   end Finalize;

   function Count (S : Storage) return Natural is (S.Length);

   function Capacity (S : Storage) return Natural is
     (if S.Arena = null then 0 else S.Arena.Capacity);

   function Is_Full (S : Storage) return Boolean is
     (S.Arena = null or else S.Length >= Capacity (S));

   function Commands (S : Storage) return RM.Image_Array_View is
     (if S.Arena = null
      then null
      else RM.Image_Array_View (S.Arena.Published));

   function Element
     (S     : Storage;
      Index : Positive) return RM.Image_Command
   is
   begin
      if Index > S.Length then
         raise Constraint_Error with "frame image command index out of bounds";
      end if;
      return S.Arena.Published (Index);
   end Element;
end Terminal.App.Frame_Image_Storage;
