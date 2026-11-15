with Terminal.App.Image_Store;
with Terminal.App.Renderer.Placement_State;
with Terminal.Common.Counters;

package body Terminal.App.Renderer.Image_Objects is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;

   function Find
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_ID
         (R.Graphics_State.Resources.Image_Objects, Stream_ID, ID));

   function Find_By_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_Storage_Order
         (R.Graphics_State.Resources.Image_Objects, Stream_ID, Storage_Order));

   function Find_By_Number
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_Number
         (R.Graphics_State.Resources.Image_Objects, Stream_ID, Number));

   function Stored_Root_Length (Object : Image_Object_Access) return Natural is
     (Terminal.App.Image_Store.Root_Data_Length (Object));

   function Stored_Indexed_Length
     (Object : Image_Object_Access) return Natural is
     (Terminal.App.Image_Store.Indexed_Data_Allocation_Length (Object));

   function Has_Stored_Root (Object : Image_Object_Access) return Boolean is
     (Stored_Root_Length (Object) > 0);

   function Has_Stored_Indexed (Object : Image_Object_Access) return Boolean is
     (Stored_Indexed_Length (Object) > 0);

   function Stored_Bytes (R : Renderer) return Natural is
     (Terminal.App.Image_Store.Byte_Count
        (R.Graphics_State.Resources.Image_Objects));

   function Stored_Animation_Frame_Count (R : Renderer) return Natural is
     (Terminal.App.Image_Store.Animation_Frame_Count
        (R.Graphics_State.Resources.Image_Objects));

   function Allocate_ID
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
      return Terminal.Core.Graphics_ID
   is
      Candidate : Terminal.Core.Graphics_ID :=
        R.Graphics_State.Transaction.Next_Automatic_Image_ID;
   begin
      if Candidate = 0 then
         Candidate := 1;
      end if;

      --  At most Max_Kitty_Image_Objects objects can exist, so this bounded
      --  scan always finds a free non-zero identifier when storage is not
      --  already full.
      for Attempt in 0 .. Max_Kitty_Image_Objects loop
         if Find (R, Stream_ID, Candidate) = null then
            R.Graphics_State.Transaction.Next_Automatic_Image_ID :=
              Candidate + 1;
            if R.Graphics_State.Transaction.Next_Automatic_Image_ID = 0 then
               R.Graphics_State.Transaction.Next_Automatic_Image_ID := 1;
            end if;
            return Candidate;
         end if;
         Candidate := Candidate + 1;
         if Candidate = 0 then
            Candidate := 1;
         end if;
      end loop;
      return 0;
   end Allocate_ID;

   procedure Release_All (R : in out Renderer) is
   begin
      Terminal.App.Image_Store.Release_All
        (R.Graphics_State.Resources.Image_Objects);
      Terminal.App.Renderer.Placement_State.Release_All (R);
   end Release_All;

   procedure Touch
     (R : in out Renderer; Object : Image_Object_Access) is
   begin
      Terminal.App.Image_Store.Touch
        (R.Graphics_State.Resources.Image_Objects, Object);
      R.Graphics_State.Animation_Schedule_Valid := False;
   end Touch;

   procedure Delete_Object
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID)
   is
      Object : constant Image_Object_Access := Find (R, Stream_ID, ID);
   begin
      if Object /= null then
         Delete_By_Storage_Order (R, Stream_ID, Object.Storage_Order);
      end if;
   end Delete_Object;

   procedure Delete_ID_Range
     (R           : in out Renderer;
      Stream_ID   : Terminal.Core.Graphics_Stream_ID;
      First_ID    : Terminal.Core.Graphics_ID;
      Last_ID     : Terminal.Core.Graphics_ID;
      Delete_Data : Boolean)
   is
      Virtual_Position : Placement_State.Virtual_Cursor :=
        Placement_State.First_Virtual (R);
      Conventional_Position : Placement_State.Conventional_Cursor :=
        Placement_State.First_Conventional (R);
      Object_Current : Image_Object_Access :=
        Terminal.App.Image_Store.First
          (R.Graphics_State.Resources.Image_Objects);
   begin
      if Last_ID < First_ID then
         return;
      end if;
      while Placement_State.Has_Element (Virtual_Position) loop
         declare
            Value : constant Virtual_Placement_State :=
              Placement_State.Element (Virtual_Position);
         begin
            if Value.Stream_ID = Stream_ID
              and then Value.Image_ID in First_ID .. Last_ID
            then
               Placement_State.Delete (R, Virtual_Position);
            else
               Placement_State.Advance (Virtual_Position);
            end if;
         end;
      end loop;
      while Placement_State.Has_Element (Conventional_Position) loop
         declare
            Value : constant Conventional_Placement_State :=
              Placement_State.Element (Conventional_Position);
         begin
            if Value.Stream_ID = Stream_ID
              and then Value.Protocol = Terminal.App.Render_Model.Image_Kitty
              and then Value.Image_ID in First_ID .. Last_ID
            then
               Placement_State.Delete (R, Conventional_Position);
            else
               Placement_State.Advance (Conventional_Position);
            end if;
         end;
      end loop;
      if Delete_Data then
         while Object_Current /= null loop
            declare
               Next : constant Image_Object_Access :=
                 Terminal.App.Image_Store.Next_Object (Object_Current);
            begin
               if Object_Current.Stream_ID = Stream_ID
                 and then Object_Current.Protocol =
                   Terminal.App.Render_Model.Image_Kitty
                 and then Object_Current.ID in First_ID .. Last_ID
               then
                  Delete_By_Storage_Order
                    (R, Stream_ID, Object_Current.Storage_Order);
               end if;
               Object_Current := Next;
            end;
         end loop;
      end if;
   end Delete_ID_Range;

   procedure Delete_By_Storage_Order
     (R             : in out Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64;
      Counted       : Boolean := True)
   is
      Current : Image_Object_Access :=
        Terminal.App.Image_Store.Find_By_Storage_Order
          (R.Graphics_State.Resources.Image_Objects, Stream_ID, Storage_Order);
      Virtual_Position : Terminal.App.Renderer.Placement_State.Virtual_Cursor :=
        Terminal.App.Renderer.Placement_State.First_Virtual (R);
      Conventional_Position :
        Terminal.App.Renderer.Placement_State.Conventional_Cursor :=
          Terminal.App.Renderer.Placement_State.First_Conventional (R);
      Preparation : Terminal.App.Image_Store.Delete_Preparation;
   begin
      if Storage_Order = 0 then
         return;
      end if;
      if Current = null then
         return;
      end if;

      if Counted then
         Terminal.App.Image_Store.Prepare_Delete_Object
           (R.Graphics_State.Resources.Image_Objects, Current, Preparation);
      else
         Terminal.App.Image_Store.Prepare_Delete_Replacement
           (R.Graphics_State.Resources.Image_Objects, Current, Preparation);
      end if;

      --  Validate every affected placement before releasing the first one.
      --  Index inconsistencies therefore cannot turn an image deletion into
      --  a partially applied placement deletion.
      declare
         Position : Terminal.App.Renderer.Placement_State.Virtual_Cursor :=
           Virtual_Position;
      begin
         while Terminal.App.Renderer.Placement_State.Has_Element (Position) loop
            declare
               Value : constant Virtual_Placement_State :=
                 Terminal.App.Renderer.Placement_State.Element (Position);
            begin
               if Value.Stream_ID = Stream_ID
                 and then Value.Image_Storage_Order = Storage_Order
               then
                  Terminal.App.Renderer.Placement_State.Validate_Delete
                    (R, Position);
               end if;
               Terminal.App.Renderer.Placement_State.Advance (Position);
            end;
         end loop;
      end;
      declare
         Position :
           Terminal.App.Renderer.Placement_State.Conventional_Cursor :=
             Conventional_Position;
      begin
         while Terminal.App.Renderer.Placement_State.Has_Element (Position) loop
            declare
               Value : constant
                 Conventional_Placement_State :=
                   Terminal.App.Renderer.Placement_State.Element (Position);
            begin
               if Value.Stream_ID = Stream_ID
                 and then Value.Image_Storage_Order = Storage_Order
               then
                  Terminal.App.Renderer.Placement_State.Validate_Delete
                    (R, Position);
               end if;
               Terminal.App.Renderer.Placement_State.Advance (Position);
            end;
         end loop;
      end;

      Terminal.App.Renderer.Placement_State.Invalidate_Placement_Index (R);
      while Terminal.App.Renderer.Placement_State.Has_Element
        (Virtual_Position)
      loop
         declare
            Virtual_Current : constant Virtual_Placement_State :=
              Terminal.App.Renderer.Placement_State.Element
                (Virtual_Position);
         begin
            if Virtual_Current.Stream_ID = Stream_ID
              and then Virtual_Current.Image_Storage_Order = Storage_Order
            then
               Terminal.App.Renderer.Placement_State.Delete
                 (R, Virtual_Position);
            else
               Terminal.App.Renderer.Placement_State.Advance
                 (Virtual_Position);
            end if;
         end;
      end loop;
      while Terminal.App.Renderer.Placement_State.Has_Element
        (Conventional_Position)
      loop
         declare
            Conventional_Current : constant
              Conventional_Placement_State :=
              Terminal.App.Renderer.Placement_State.Element
                (Conventional_Position);
         begin
            if Conventional_Current.Stream_ID = Stream_ID
              and then Conventional_Current.Image_Storage_Order = Storage_Order
            then
               Terminal.App.Renderer.Placement_State.Delete
                 (R, Conventional_Position);
            else
               Terminal.App.Renderer.Placement_State.Advance
                 (Conventional_Position);
            end if;
         end;
      end loop;
      if Counted then
         Terminal.App.Image_Store.Delete_Object
           (R.Graphics_State.Resources.Image_Objects,
            Current,
            Preparation);
      else
         Terminal.App.Image_Store.Delete_Replacement
           (R.Graphics_State.Resources.Image_Objects,
            Current,
            Preparation);
      end if;
   end Delete_By_Storage_Order;

   function Evict_One_Unplaced
     (R                 : in out Renderer;
      Preserve_Stream   : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
      Current : Image_Object_Access :=
        Terminal.App.Image_Store.First
          (R.Graphics_State.Resources.Image_Objects);
      Candidate : Image_Object_Access := null;
   begin
      while Current /= null loop
         if not
           (Preserve_Image_ID /= 0
            and then Current.Stream_ID = Preserve_Stream
            and then Current.ID = Preserve_Image_ID)
           and then not Terminal.App.Renderer.Placement_State.Has_Image_Placement
             (R, Current)
           and then
             (Candidate = null
              or else
                (Current.Usage_Hint = 1 and then Candidate.Usage_Hint /= 1)
              or else
                (Current.Usage_Hint = Candidate.Usage_Hint
                 and then Current.Storage_Order < Candidate.Storage_Order))
         then
            Candidate := Current;
         end if;
         Current := Terminal.App.Image_Store.Next_Object (Current);
      end loop;
      if Candidate = null then
         return False;
      end if;
      Delete_By_Storage_Order
        (R, Candidate.Stream_ID, Candidate.Storage_Order);
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Image_Eviction_Count);
      return True;
   end Evict_One_Unplaced;
end Terminal.App.Renderer.Image_Objects;
