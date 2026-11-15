with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Upload_Layout;
with Terminal.App.Image_Store.Indexes;
with Terminal.App.Image_Store.Data_Borrows;
with Terminal.App.Image_Store.Object_Lifecycle;
with Terminal.App.Image_Store.Accounting;
with Terminal.App.Owned_Image_Data;
with System;
with System.Storage_Elements;

package body Terminal.App.Image_Store is
   use type Ada.Containers.Hash_Type;
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;

   function Hash_Object_Key
     (Key : Object_Key) return Ada.Containers.Hash_Type is
   begin
      return Ada.Containers.Hash_Type'Mod (Key.Stream_ID) * 16#0100_0193#
        xor Ada.Containers.Hash_Type'Mod (Key.Value);
   end Hash_Object_Key;

   function Hash_Storage_Key
     (Key : Storage_Key) return Ada.Containers.Hash_Type is
   begin
      return Ada.Containers.Hash_Type'Mod (Key.Stream_ID) * 16#0100_0193#
        xor Ada.Containers.Hash_Type'Mod (Key.Storage_Order);
   end Hash_Storage_Key;

   procedure Advance_Mutation_Epoch (Container : in out Store) is
   begin
      Container.Mutation_Epoch := Container.Mutation_Epoch + 1;
      if Container.Mutation_Epoch = 0 then
         Container.Mutation_Epoch := 1;
      end if;
   end Advance_Mutation_Epoch;
   use type System.Address;

   function Hash_Address (Value : System.Address) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type'Mod
        (System.Storage_Elements.To_Integer (Value)));

   procedure Free_Image_Frame is new Ada.Unchecked_Deallocation
     (Image_Frame, Image_Frame_Access);
   procedure Free_Image_Frame_Index is new Ada.Unchecked_Deallocation
     (Image_Frame_Index_Array, Image_Frame_Index_Access);
   procedure Free_Theme_Operation is new Ada.Unchecked_Deallocation
     (Theme_Operation, Theme_Operation_Access);
   procedure Free_Image_Object is new Ada.Unchecked_Deallocation
     (Image_Object, Image_Object_Access);

   type Image_Reclaimer is
     new Ada.Finalization.Limited_Controlled with record
      Object : Image_Object_Access := null;
   end record;
   overriding procedure Finalize (Item : in out Image_Reclaimer);

   overriding procedure Finalize (Item : in out Image_Reclaimer) is
      Released : Image_Object_Access := Item.Object;
   begin
      Item.Object := null;
      if Released /= null then
         begin
            Release_Contents (Released.all);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage,
                  E,
                  "release reclaimed image contents");
         end;
         begin
            --  The object has already been detached from every store and its
            --  last borrow released.  Do not lose the allocation merely
            --  because best-effort release of one owned payload failed.
            Free_Image_Object (Released);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage,
                  E,
                  "free reclaimed image object");
         end;
      end if;
   end Finalize;

   procedure Assert_Not_Borrowed (Object : Image_Object) is
   begin
      if Object.State.Frame_Borrows /= 0 then
         raise Program_Error with
           "cannot invalidate image data borrowed by the current frame";
      end if;
   end Assert_Not_Borrowed;

   protected Borrow_Ownership_Gate is
      procedure Acquire
        (Object : Image_Object_Access;
         Hold   : in out Frame_Borrow_Hold);
      procedure Release
        (Hold      : in out Frame_Borrow_Hold;
         Reclaimer : in out Image_Reclaimer);
      procedure Move
        (Source : in out Frame_Borrow_Hold;
         Target : in out Frame_Borrow_Hold);
   end Borrow_Ownership_Gate;

   protected body Borrow_Ownership_Gate is
      procedure Acquire
        (Object : Image_Object_Access;
         Hold   : in out Frame_Borrow_Hold) is
      begin
         if Hold.Object /= null then
            raise Program_Error with "image frame-borrow hold is already active";
         elsif Object = null then
            Hold.Token := 0;
            return;
         elsif Object.State.Frame_Borrows = Natural'Last then
            raise Constraint_Error with "image frame-borrow count overflow";
         end if;
         Object.State.Frame_Borrows := Object.State.Frame_Borrows + 1;
         Hold.Object := Object;
      end Acquire;

      procedure Release
        (Hold      : in out Frame_Borrow_Hold;
         Reclaimer : in out Image_Reclaimer) is
      begin
         if Reclaimer.Object /= null then
            raise Program_Error with "image reclaimer is already active";
         elsif Hold.Object = null then
            Hold.Token := 0;
            return;
         elsif Hold.Object.State.Frame_Borrows = 0 then
            raise Program_Error with "unbalanced image frame borrow";
         end if;
         Hold.Object.State.Frame_Borrows :=
           Hold.Object.State.Frame_Borrows - 1;
         if Hold.Object.State.Frame_Borrows = 0
           and then Hold.Object.State.Pending_Release
         then
            Reclaimer.Object := Hold.Object;
         end if;
         Hold.Object := null;
         Hold.Token := 0;
      end Release;

      procedure Move
        (Source : in out Frame_Borrow_Hold;
         Target : in out Frame_Borrow_Hold) is
      begin
         if Target.Object /= null then
            raise Program_Error with
              "image frame-borrow target is already active";
         end if;
         Target.Object := Source.Object;
         Target.Token := Source.Token;
         Source.Object := null;
         Source.Token := 0;
      end Move;
   end Borrow_Ownership_Gate;

   procedure Acquire_Frame_Borrow
     (Object : Image_Object_Access;
      Hold   : in out Frame_Borrow_Hold) is
   begin
      Borrow_Ownership_Gate.Acquire (Object, Hold);
   end Acquire_Frame_Borrow;

   procedure Release_Frame_Borrow (Hold : in out Frame_Borrow_Hold) is
      Reclaimer : Image_Reclaimer;
   begin
      Borrow_Ownership_Gate.Release (Hold, Reclaimer);
   end Release_Frame_Borrow;

   procedure Move_Frame_Borrow
     (Source : in out Frame_Borrow_Hold;
      Target : in out Frame_Borrow_Hold) is
   begin
      Borrow_Ownership_Gate.Move (Source, Target);
   end Move_Frame_Borrow;

   procedure Borrow
     (Item   : in out Data_Borrow;
      Object : Image_Object_Access) is
   begin
      Data_Borrows.Acquire (Item, Object);
   end Borrow;

   procedure Release (Item : in out Data_Borrow) is
   begin
      Data_Borrows.Release (Item);
   end Release;

   overriding procedure Finalize (Item : in out Data_Borrow) is
   begin
      Release (Item);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage,
            E,
            "release image-data borrow");
   end Finalize;

   function Borrowed_Root_Length (Item : Data_Borrow) return Natural is
     (Data_Borrows.Root_Length (Item));

   function Borrowed_Indexed_Length (Item : Data_Borrow) return Natural is
     (Data_Borrows.Indexed_Length (Item));

   procedure Visit_Borrowed_Frame_Data
     (Item   : Data_Borrow;
      Number : Positive;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array))
   is
      View : constant Terminal.App.Render_Model.Image_Data_View :=
        Data_Borrows.Frame_Data (Item, Number);
   begin
      if View /= null then
         Process (View.all);
      end if;
   end Visit_Borrowed_Frame_Data;

   procedure Copy_Root_Data
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array)
   is
   begin
      Data_Borrows.Copy_Root (Item, Target);
   end Copy_Root_Data;

   procedure Copy_Indexed_Data
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array)
   is
   begin
      Data_Borrows.Copy_Indexed (Item, Target);
   end Copy_Indexed_Data;

   function Root_Data_Length (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      else Terminal.App.Owned_Image_Data.Length (Object.Bytes));

   function Indexed_Data_Allocation_Length
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      else Terminal.App.Owned_Image_Data.Length (Object.Indexed_Bytes));

   procedure Create_Object (Object : out Image_Object_Access) is
   begin
      Object_Lifecycle.Create (Object);
   end Create_Object;

   procedure Release_Unowned_Object (Object : in out Image_Object_Access) is
   begin
      Object_Lifecycle.Release_Unowned (Object);
   end Release_Unowned_Object;

   function Stream_ID (Object : Image_Object) return Terminal.Core.Graphics_Stream_ID is
     (Object.State.Stream_ID);
   function ID (Object : Image_Object) return Terminal.Core.Graphics_ID is
     (Object.State.ID);
   function Number (Object : Image_Object) return Terminal.Core.Graphics_ID is
     (Object.State.Number);
   function Protocol
     (Object : Image_Object) return Terminal.App.Render_Model.Image_Protocol is
     (Object.State.Protocol);
   function Raw_Format (Object : Image_Object) return Natural is
     (Object.State.Raw_Format);
   function Pixel_Width (Object : Image_Object) return Natural is
     (Object.State.Pixel_Width);
   function Pixel_Height (Object : Image_Object) return Natural is
     (Object.State.Pixel_Height);
   function Decoded_Length (Object : Image_Object) return Natural is
     (Object.State.Decoded_Length);
   function Decoded_Row_Stride_Bytes (Object : Image_Object) return Natural is
     (Object.State.Decoded_Row_Stride_Bytes);
   function Usage_Hint (Object : Image_Object) return Natural is
     (Object.State.Usage_Hint);
   function Storage_Order (Object : Image_Object) return Interfaces.Unsigned_64 is
     (Object.State.Storage_Order);
   function Content_Serial (Object : Image_Object) return Interfaces.Unsigned_64 is
     (Object.State.Content_Serial);
   procedure Set_Usage_Hint
     (Container : in out Store;
      Object    : Image_Object_Access;
      Value     : Natural) is
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Object.State.Usage_Hint := Value;
   end Set_Usage_Hint;
   procedure Release_Frame_List (Head : in out Image_Frame_Access) is
      Current : Image_Frame_Access := Head;
   begin
      while Current /= null loop
         declare
            Following : constant Image_Frame_Access := Current.Next;
         begin
            Terminal.App.Owned_Image_Data.Release (Current.Bytes);
            Free_Image_Frame (Current);
            Current := Following;
         end;
      end loop;
      Head := null;
   end Release_Frame_List;

   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access)
   is
      Current : Theme_Operation_Access := Head;
   begin
      while Current /= null loop
         declare
            Following : constant Theme_Operation_Access := Current.Next;
         begin
            Terminal.App.Owned_Image_Data.Release (Current.Bytes);
            Free_Theme_Operation (Current);
            Current := Following;
         end;
      end loop;
      Head := null;
   end Release_Theme_Operation_List;

   function Find_By_ID
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Key : constant Object_Key := (Stream_ID, ID);
   begin
      if ID = 0 then
         return null;
      elsif Container.By_ID.Contains (Key) then
         return Container.By_ID.Element (Key);
      else
         return null;
      end if;
   end Find_By_ID;

   function Find_By_Number
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Key : constant Object_Key := (Stream_ID, Number);
   begin
      if Number = 0 then
         return null;
      elsif Container.By_Number.Contains (Key) then
         return Container.By_Number.Element (Key);
      else
         return null;
      end if;
   end Find_By_Number;

   function Find_By_Storage_Order
     (Container     : Store;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is
      Key : constant Storage_Key := (Stream_ID, Storage_Order);
   begin
      if Storage_Order = 0 then
         return null;
      elsif Container.By_Storage_Order.Contains (Key) then
         return Container.By_Storage_Order.Element (Key);
      else
         return null;
      end if;
   end Find_By_Storage_Order;

   function Owned_Bytes (Object : Image_Object) return Natural is
      Result : Natural := 0;

      procedure Add (Amount : Natural) is
      begin
         if Amount > Natural'Last - Result then
            Result := Natural'Last;
         else
            Result := Result + Amount;
         end if;
      end Add;
   begin
      Add (Terminal.App.Owned_Image_Data.Length (Object.Bytes));
      Add (Terminal.App.Owned_Image_Data.Length (Object.Indexed_Bytes));
      Add (Object.State.Frame_Bytes);
      Add (Object.State.Theme_Operation_Bytes);
      return Result;
   end Owned_Bytes;

   function Root_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View is
     (if Object = null then null
      else Terminal.App.Owned_Image_Data.Unsafe_View (Object.Bytes));

   function Indexed_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View is
     (if Object = null then null
      else Terminal.App.Owned_Image_Data.Unsafe_View (Object.Indexed_Bytes));

   function Owns_Data_View
     (Object : Image_Object_Access;
      Data   : Terminal.App.Render_Model.Image_Data_View) return Boolean
   is
      Frame : Image_Frame_Access;
      Operation : Theme_Operation_Access;
   begin
      if Data = null then
         return True;
      elsif Object = null then
         return False;
      elsif Terminal.App.Owned_Image_Data.Owns (Object.Bytes, Data)
        or else Terminal.App.Owned_Image_Data.Owns (Object.Indexed_Bytes, Data)
      then
         return True;
      end if;
      Frame := Object.State.Frames;
      while Frame /= null loop
         if Terminal.App.Owned_Image_Data.Owns (Frame.Bytes, Data) then
            return True;
         end if;
         Frame := Frame.Next;
      end loop;
      Operation := Object.State.Theme_Operations;
      while Operation /= null loop
         if Terminal.App.Owned_Image_Data.Owns (Operation.Bytes, Data) then
            return True;
         end if;
         Operation := Operation.Next;
      end loop;
      return False;
   end Owns_Data_View;

   function Indexed_Data_Format
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.State.Indexed_Format);

   function Indexed_Data_Length
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.State.Indexed_Length);

   function Indexed_Row_Stride
     (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.State.Indexed_Row_Stride_Bytes);

   procedure Release_Contents (Object : in out Image_Object) is
      Frame : Image_Frame_Access := Object.State.Frames;
      Operation : Theme_Operation_Access := Object.State.Theme_Operations;
   begin
      Assert_Not_Borrowed (Object);
      Release_Frame_List (Frame);
      Free_Image_Frame_Index (Object.State.Frame_Index);
      Release_Theme_Operation_List (Operation);
      Terminal.App.Owned_Image_Data.Release (Object.Bytes);
      Terminal.App.Owned_Image_Data.Release (Object.Indexed_Bytes);
      Object.State := (others => <>);
   end Release_Contents;

   function First (Container : Store) return Image_Object_Access is
     (Container.Head);

   function Next_Object
     (Object : Image_Object_Access) return Image_Object_Access is
     (if Object = null then null else Object.Next);

   function Object_Count (Container : Store) return Natural is
     (Container.Objects);

   function Byte_Count (Container : Store) return Natural is
     (Container.Bytes);

   function Animation_Frame_Count (Container : Store) return Natural is
     (Container.Animation_Frames);

   function Checked_Total (Left, Right : Natural) return Natural is
   begin
      if Right > Natural'Last - Left then
         raise Storage_Error with "image store accounting overflow";
      end if;
      return Left + Right;
   end Checked_Total;

   function Bytes_Per_Pixel (Format : Natural) return Natural is
     (case Format is
         when 8      => 1,
         when 16     => 2,
         when 24     => 3,
         when 32     => 4,
         when others => 0);

   procedure Validate_Pixel_Data
     (Format       : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Stride   : Natural;
      Length       : Natural)
   is
      Pixel_Size : constant Natural := Bytes_Per_Pixel (Format);
      Required : Natural;
   begin
      if Pixel_Size = 0 or else Pixel_Width = 0 or else Pixel_Height = 0 then
         raise Constraint_Error with "invalid image geometry or format";
      end if;
      Required := Terminal.App.Image_Upload_Layout.Required_Source_Bytes
        (Pixel_Width,
         Pixel_Height,
         Pixel_Size,
         Row_Stride,
         Natural'Last);
      if Required = 0 or else Length < Required then
         raise Constraint_Error with "image data does not match its layout";
      end if;
   end Validate_Pixel_Data;

   function Is_Owned
     (Container : Store;
      Object    : Image_Object_Access) return Boolean
   is (Object /= null and then Object.Owner = Container'Address);

   procedure Synchronize
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
   begin
      Accounting.Synchronize (Container, Object);
   end Synchronize;


   procedure Adopt_Indexed_Data
     (Container  : in out Store;
      Object     : Image_Object_Access;
      Format     : Natural;
      Row_Stride : Natural;
      Data       : in out Terminal.App.Owned_Image_Data.Owner)
   is
      Previous_Data : Terminal.App.Owned_Image_Data.Owner;
      Previous_Format : Natural;
      Previous_Length : Natural;
      Previous_Stride : Natural;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Data) then
         raise Constraint_Error with "cannot adopt null indexed image data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Assert_Not_Borrowed (Object.all);
      if Format not in 8 | 16 then
         raise Constraint_Error with "indexed image format must be 8 or 16";
      end if;
      Validate_Pixel_Data
        (Format, Object.State.Pixel_Width, Object.State.Pixel_Height,
         Row_Stride, Terminal.App.Owned_Image_Data.Length (Data));
      if Owns_Data_View
        (Object, Terminal.App.Owned_Image_Data.Unsafe_View (Data))
      then
         raise Program_Error with "indexed image data aliases owned storage";
      end if;
      Previous_Format := Object.State.Indexed_Format;
      Previous_Length := Object.State.Indexed_Length;
      Previous_Stride := Object.State.Indexed_Row_Stride_Bytes;
      Terminal.App.Owned_Image_Data.Move
        (Object.Indexed_Bytes, Previous_Data);
      Terminal.App.Owned_Image_Data.Move (Data, Object.Indexed_Bytes);
      Object.State.Indexed_Format := Format;
      Object.State.Indexed_Length :=
        Terminal.App.Owned_Image_Data.Length (Object.Indexed_Bytes);
      Object.State.Indexed_Row_Stride_Bytes := Row_Stride;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Terminal.App.Owned_Image_Data.Move
              (Object.Indexed_Bytes, Data);
            Terminal.App.Owned_Image_Data.Move
              (Previous_Data, Object.Indexed_Bytes);
            Object.State.Indexed_Format := Previous_Format;
            Object.State.Indexed_Length := Previous_Length;
            Object.State.Indexed_Row_Stride_Bytes := Previous_Stride;
            raise;
      end;
      Terminal.App.Owned_Image_Data.Release (Previous_Data);
   end Adopt_Indexed_Data;

   procedure Replace_Root_RGBA
     (Container : in out Store;
      Object    : Image_Object_Access;
      Data      : in out Terminal.App.Owned_Image_Data.Owner;
      Preserve_Indexed : Boolean := False;
      Set_Root_Gap : Boolean := False;
      Root_Gap_MS  : Integer := 0;
      Set_Usage    : Boolean := False;
      Usage_Hint   : Natural := 0)
   is
      Previous_Data : Terminal.App.Owned_Image_Data.Owner;
      Previous_Indexed : Terminal.App.Owned_Image_Data.Owner;
      Previous_Format : Natural;
      Previous_Length : Natural;
      Previous_Stride : Natural;
      Previous_Indexed_Format : Natural;
      Previous_Indexed_Length : Natural;
      Previous_Indexed_Stride : Natural;
      Previous_Root_Gap : Integer;
      Previous_Usage : Natural;
   begin
      if Terminal.App.Owned_Image_Data.Is_Empty (Data) then
         raise Constraint_Error with "cannot install null RGBA image data";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Owns_Data_View
        (Object, Terminal.App.Owned_Image_Data.Unsafe_View (Data))
      then
         raise Program_Error with "RGBA image data aliases owned storage";
      elsif Object.State.Pixel_Width > Natural'Last / 4 then
         raise Constraint_Error with "RGBA row stride overflows";
      end if;
      Assert_Not_Borrowed (Object.all);
      Validate_Pixel_Data
        (32, Object.State.Pixel_Width, Object.State.Pixel_Height,
         Object.State.Pixel_Width * 4,
         Terminal.App.Owned_Image_Data.Length (Data));

      Previous_Format := Object.State.Raw_Format;
      Previous_Length := Object.State.Decoded_Length;
      Previous_Stride := Object.State.Decoded_Row_Stride_Bytes;
      Previous_Indexed_Format := Object.State.Indexed_Format;
      Previous_Indexed_Length := Object.State.Indexed_Length;
      Previous_Indexed_Stride := Object.State.Indexed_Row_Stride_Bytes;
      Previous_Root_Gap := Object.State.Root_Gap_MS;
      Previous_Usage := Object.State.Usage_Hint;
      Terminal.App.Owned_Image_Data.Move (Object.Bytes, Previous_Data);
      Terminal.App.Owned_Image_Data.Move (Data, Object.Bytes);
      Object.State.Raw_Format := 32;
      Object.State.Decoded_Length :=
        Terminal.App.Owned_Image_Data.Length (Object.Bytes);
      Object.State.Decoded_Row_Stride_Bytes := Object.State.Pixel_Width * 4;
      if not Preserve_Indexed then
         Object.State.Indexed_Format := 0;
         Object.State.Indexed_Length := 0;
         Object.State.Indexed_Row_Stride_Bytes := 0;
         Terminal.App.Owned_Image_Data.Move
           (Object.Indexed_Bytes, Previous_Indexed);
      end if;
      if Set_Root_Gap then
         Object.State.Root_Gap_MS := Root_Gap_MS;
      end if;
      if Set_Usage then
         Object.State.Usage_Hint := Usage_Hint;
      end if;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Terminal.App.Owned_Image_Data.Move (Object.Bytes, Data);
            Terminal.App.Owned_Image_Data.Move (Previous_Data, Object.Bytes);
            Object.State.Raw_Format := Previous_Format;
            Object.State.Decoded_Length := Previous_Length;
            Object.State.Decoded_Row_Stride_Bytes := Previous_Stride;
            Object.State.Indexed_Format := Previous_Indexed_Format;
            Object.State.Indexed_Length := Previous_Indexed_Length;
            Object.State.Indexed_Row_Stride_Bytes := Previous_Indexed_Stride;
            if not Preserve_Indexed then
               Terminal.App.Owned_Image_Data.Move
                 (Previous_Indexed, Object.Indexed_Bytes);
            end if;
            Object.State.Root_Gap_MS := Previous_Root_Gap;
            Object.State.Usage_Hint := Previous_Usage;
            raise;
      end;
      Terminal.App.Owned_Image_Data.Release (Previous_Data);
      Terminal.App.Owned_Image_Data.Release (Previous_Indexed);
   end Replace_Root_RGBA;

   procedure Install_Root
     (Container        : in out Store;
      Object           : Image_Object_Access;
      Stream_ID        : Terminal.Core.Graphics_Stream_ID;
      ID               : Terminal.Core.Graphics_ID;
      Number           : Terminal.Core.Graphics_ID;
      Protocol         : Terminal.App.Render_Model.Image_Protocol;
      Raw_Format       : Natural;
      Pixel_Width      : Natural;
      Pixel_Height     : Natural;
      Decoded_Length   : Natural;
      Row_Stride       : Natural;
      Usage_Hint       : Natural;
      Data             : in out Terminal.App.Owned_Image_Data.Owner;
      Index_Control    : access Allocation_Control := null)
   is separate;

   procedure Link_New
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      Object_Lifecycle.Link_New (Container, Object);
   end Link_New;

   procedure Link_Replacement
     (Container : in out Store;
      Object    : Image_Object_Access;
      Replaced  : Image_Object_Access) is
   begin
      Object_Lifecycle.Link_Replacement (Container, Object, Replaced);
   end Link_Replacement;

   procedure Prepare_Delete
     (Container              : Store;
      Object                 : Image_Object_Access;
      Counted                : Boolean;
      Validate_Indexes       : Boolean;
      Previous               : out Image_Object_Access;
      Current                : out Image_Object_Access;
      Replacement_To_Promote : out Image_Object_Access)
   is
   begin
      Previous := null;
      Current := Object;
      Replacement_To_Promote := null;
      if Object = null then
         return;
      end if;
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Previous := Current.Previous;
      if (Previous = null and then Container.Head /= Current)
        or else (Previous /= null and then Previous.Next /= Current)
      then
         raise Program_Error with "image object list is inconsistent";
      elsif Current.State.Theme_Transaction_Active
        and then not Current.State.Theme_Transaction_Quarantined
      then
         raise Program_Error with "cannot delete an object during a theme transaction";
      end if;
      if Counted and then not Current.Counted then
         raise Program_Error with "replacement object is not committed";
      elsif Counted and then Current.Counted then
         if Current.Pending_Replacement /= null then
            raise Program_Error with
              "cannot delete an object with a pending replacement";
         end if;
      elsif not Counted and then Current.Counted then
         Replacement_To_Promote := Current.Pending_Replacement;
         if Replacement_To_Promote = null then
            raise Program_Error with "replacement object is missing";
         end if;
      end if;
      if (Current.Counted and then Container.Objects = 0)
        or else Container.Bytes < Current.Accounted_Bytes
        or else Container.Animation_Frames < Current.Accounted_Frames
      then
         raise Program_Error with "image store accounting underflow";
      end if;
      if Validate_Indexes then
         Terminal.App.Image_Store.Indexes.Validate_Remove (Container, Current);
      end if;
   end Prepare_Delete;

   procedure Prepare_Delete_Object
     (Container : Store;
      Object    : Image_Object_Access;
      Preparation : out Delete_Preparation)
   is
      Previous, Current, Replacement : Image_Object_Access;
   begin
      Prepare_Delete
        (Container, Object, True, True, Previous, Current, Replacement);
      Preparation.Store_Address := Container'Address;
      Preparation.Object := Current;
      Preparation.Previous := Previous;
      Preparation.Replacement_To_Promote := Replacement;
      Preparation.Counted := True;
      Preparation.Mutation_Epoch := Container.Mutation_Epoch;
      Preparation.Valid := True;
   end Prepare_Delete_Object;

   procedure Prepare_Delete_Replacement
     (Container : Store;
      Object    : Image_Object_Access;
      Preparation : out Delete_Preparation)
   is
      Previous, Current, Replacement : Image_Object_Access;
   begin
      Prepare_Delete
        (Container, Object, False, True, Previous, Current, Replacement);
      Preparation.Store_Address := Container'Address;
      Preparation.Object := Current;
      Preparation.Previous := Previous;
      Preparation.Replacement_To_Promote := Replacement;
      Preparation.Counted := False;
      Preparation.Mutation_Epoch := Container.Mutation_Epoch;
      Preparation.Valid := True;
   end Prepare_Delete_Replacement;

   procedure Delete
     (Container : in out Store;
      Object    : in out Image_Object_Access;
      Counted   : Boolean;
      Preparation : in out Delete_Preparation)
   is
      Previous : constant Image_Object_Access := Preparation.Previous;
      Current : Image_Object_Access := Preparation.Object;
      Replacement_To_Promote : constant Image_Object_Access :=
        Preparation.Replacement_To_Promote;
   begin
      if not Preparation.Valid
        or else Preparation.Store_Address /= Container'Address
        or else Preparation.Counted /= Counted
        or else Preparation.Mutation_Epoch /= Container.Mutation_Epoch
        or else Object /= Current
      then
         raise Program_Error with "invalid image deletion preparation";
      end if;
      Preparation.Valid := False;
      if Object = null then
         return;
      end if;
      --  Index removal performs only existing-key replacement/deletion and is
      --  therefore non-allocating.  Once placement deletion begins, image
      --  removal can no longer fail because memory is exhausted.
      Terminal.App.Image_Store.Indexes.Remove (Container, Current);
      if not Current.Counted and then Current.Replaces /= null then
         Current.Replaces.Pending_Replacement := null;
      end if;
      if Replacement_To_Promote /= null then
         Replacement_To_Promote.Counted := True;
         Replacement_To_Promote.Replaces := null;
         Current.Pending_Replacement := null;
      end if;
      if Previous = null then
         Container.Head := Current.Next;
      else
         Previous.Next := Current.Next;
      end if;
      if Current.Next /= null then
         Current.Next.Previous := Previous;
      end if;
      if Counted then
         Container.Objects := Container.Objects - 1;
      end if;
      Container.Bytes := Container.Bytes - Current.Accounted_Bytes;
      Container.Animation_Frames :=
        Container.Animation_Frames - Current.Accounted_Frames;
      if Current.State.Frame_Borrows = 0 then
         Release_Contents (Current.all);
         Free_Image_Object (Current);
      else
         Current.State.Pending_Release := True;
         Current.Counted := False;
         Current.Owner := System.Null_Address;
         Current.Previous := null;
         Current.Next := null;
      end if;
      Object := null;
      Advance_Mutation_Epoch (Container);
   end Delete;

   procedure Delete_Object
     (Container : in out Store;
      Object    : in out Image_Object_Access) is
      Preparation : Delete_Preparation;
   begin
      Prepare_Delete_Object (Container, Object, Preparation);
      Delete (Container, Object, Counted => True, Preparation => Preparation);
   end Delete_Object;

   procedure Delete_Replacement
     (Container : in out Store;
      Object    : in out Image_Object_Access) is
      Preparation : Delete_Preparation;
   begin
      Prepare_Delete_Replacement (Container, Object, Preparation);
      Delete (Container, Object, Counted => False, Preparation => Preparation);
   end Delete_Replacement;

   procedure Delete_Object
     (Container   : in out Store;
      Object      : in out Image_Object_Access;
      Preparation : in out Delete_Preparation) is
   begin
      Delete (Container, Object, Counted => True, Preparation => Preparation);
   end Delete_Object;

   procedure Delete_Replacement
     (Container   : in out Store;
      Object      : in out Image_Object_Access;
      Preparation : in out Delete_Preparation) is
   begin
      Delete (Container, Object, Counted => False, Preparation => Preparation);
   end Delete_Replacement;

   procedure Release_All (Container : in out Store) is
      Current : Image_Object_Access := Container.Head;
   begin
      if Current /= null then
         Advance_Mutation_Epoch (Container);
      end if;
      while Current /= null loop
         declare
            Next : constant Image_Object_Access := Current.Next;
         begin
            if Current.State.Frame_Borrows = 0 then
               Release_Contents (Current.all);
               Free_Image_Object (Current);
            else
               Current.State.Pending_Release := True;
               Current.Counted := False;
               Current.Owner := System.Null_Address;
               Current.Previous := null;
               Current.Next := null;
            end if;
            Current := Next;
         end;
      end loop;
      Container.Head := null;
      Container.Objects := 0;
      Container.Bytes := 0;
      Container.Animation_Frames := 0;
      Container.By_ID.Clear;
      Container.By_Number.Clear;
      Container.By_Storage_Order.Clear;
   end Release_All;

   overriding procedure Finalize (Container : in out Store) is
   begin
      Release_All (Container);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Renderer_State,
            E,
            "finalize image store");
   end Finalize;

   function Allocate_Storage_Order
     (Container : in out Store) return Interfaces.Unsigned_64
   is
      Result : constant Interfaces.Unsigned_64 := Container.Next_Storage_Order;
   begin
      Container.Next_Storage_Order := Container.Next_Storage_Order + 1;
      if Container.Next_Storage_Order = 0 then
         Container.Next_Storage_Order := 1;
      end if;
      return Result;
   end Allocate_Storage_Order;

   function Allocate_Content_Serial
     (Container : in out Store) return Interfaces.Unsigned_64
   is
      Result : constant Interfaces.Unsigned_64 := Container.Next_Content_Serial;
   begin
      Container.Next_Content_Serial := Container.Next_Content_Serial + 1;
      if Container.Next_Content_Serial = 0 then
         Container.Next_Content_Serial := 1;
      end if;
      return Result;
   end Allocate_Content_Serial;

   procedure Touch
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object /= null then
         Synchronize (Container, Object);
         Mark_Content_Changed (Container, Object);
      end if;
   end Touch;

   procedure Mark_Content_Changed
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object = null or else not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Object.State.Content_Serial := Allocate_Content_Serial (Container);
   end Mark_Content_Changed;

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean is
   begin
      if Control.Remaining_Attempts = 0 then
         return True;
      end if;
      Control.Remaining_Attempts := Control.Remaining_Attempts - 1;
      return Control.Remaining_Attempts /= 0;
   end Allocation_Allowed;

end Terminal.App.Image_Store;
