package body Terminal.App.Renderer.Placement_State is
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Interfaces.Unsigned_64;

   procedure Remove_Virtual_Placement
     (R        : in out Renderer;
      Previous : Virtual_Placement_Access;
      Current  : in out Virtual_Placement_Access;
      Next     : out Virtual_Placement_Access);
   procedure Remove_Conventional_Placement
     (R        : in out Renderer;
      Previous : Conventional_Placement_Access;
      Current  : in out Conventional_Placement_Access;
      Next     : out Conventional_Placement_Access);

   function Stored_Placement_Count (R : Renderer) return Natural is
     (Terminal.App.Image_Placements.Count
        (R.Graphics_State.Resources.Placements));

   procedure Release_All (R : in out Renderer) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Release
        (R.Graphics_State.Resources.Placements);
   end Release_All;

   procedure Release_All (Object : in out Renderer_Graphics_State) is
   begin
      Terminal.App.Image_Placements.Release (Object.Resources.Placements);
   end Release_All;

   procedure Release_Unowned
     (Placement : in out Virtual_Placement_Access) is
   begin
      Terminal.App.Image_Placements.Release_Unowned (Placement);
   end Release_Unowned;

   procedure Release_Unowned
     (Placement : in out Conventional_Placement_Access) is
   begin
      Terminal.App.Image_Placements.Release_Unowned (Placement);
   end Release_Unowned;

   function First_Virtual_Placement
     (R : Renderer) return Virtual_Placement_Access is
     (Terminal.App.Image_Placements.First_Virtual
        (R.Graphics_State.Resources.Placements));

   function First_Conventional_Placement
     (R : Renderer) return Conventional_Placement_Access is
     (Terminal.App.Image_Placements.First_Conventional
        (R.Graphics_State.Resources.Placements));

   function Next_Virtual_Placement
     (Placement : Virtual_Placement_Access) return Virtual_Placement_Access is
     (Terminal.App.Image_Placements.Next (Placement));

   function Next_Conventional_Placement
     (Placement : Conventional_Placement_Access)
      return Conventional_Placement_Access is
     (Terminal.App.Image_Placements.Next (Placement));

   function First_Virtual (R : Renderer) return Virtual_Cursor is
     (Previous => null, Current => First_Virtual_Placement (R));

   function First_Conventional (R : Renderer) return Conventional_Cursor is
     (Previous => null, Current => First_Conventional_Placement (R));

   function Has_Element (Position : Virtual_Cursor) return Boolean is
     (Position.Current /= null);

   function Has_Element (Position : Conventional_Cursor) return Boolean is
     (Position.Current /= null);

   function Value_Of
     (Placement : Virtual_Placement_Access) return Virtual_Placement_Value is
   begin
      if Placement = null then
         return (Exists => False, Value => (others => <>));
      else
         return
           (Exists => True,
            Value => Terminal.App.Image_Placements.State (Placement));
      end if;
   end Value_Of;

   function Value_Of
     (Placement : Conventional_Placement_Access)
      return Conventional_Placement_Value is
   begin
      if Placement = null then
         return (Exists => False, Value => (others => <>));
      else
         return
           (Exists => True,
            Value => Terminal.App.Image_Placements.State (Placement));
      end if;
   end Value_Of;

   function Element
     (Position : Virtual_Cursor) return Virtual_Placement_State is
     (Terminal.App.Image_Placements.State (Position.Current));

   function Element
     (Position : Conventional_Cursor) return Conventional_Placement_State is
     (Terminal.App.Image_Placements.State (Position.Current));

   procedure Update
     (R        : in out Renderer;
      Position : Virtual_Cursor;
      Process  : not null access procedure
        (Placement : in out Virtual_Placement_State)) is
   begin
      if Position.Current = null then
         raise Constraint_Error with "virtual placement cursor has no element";
      end if;
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update
        (R.Graphics_State.Resources.Placements,
         Position.Current,
         Process);
   end Update;

   procedure Update_All
     (R       : in out Renderer;
      Process : not null access procedure
        (Placement : in out Virtual_Placement_State)) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update_All
        (R.Graphics_State.Resources.Placements, Process);
   end Update_All;

   procedure Update_All
     (R       : in out Renderer;
      Process : not null access procedure
        (Placement : in out Conventional_Placement_State)) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update_All
        (R.Graphics_State.Resources.Placements, Process);
   end Update_All;

   procedure Update
     (R        : in out Renderer;
      Position : Conventional_Cursor;
      Process  : not null access procedure
        (Placement : in out Conventional_Placement_State)) is
   begin
      if Position.Current = null then
         raise Constraint_Error with
           "conventional placement cursor has no element";
      end if;
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update
        (R.Graphics_State.Resources.Placements,
         Position.Current,
         Process);
   end Update;

   procedure Advance (Position : in out Virtual_Cursor) is
   begin
      if Position.Current /= null then
         Position.Previous := Position.Current;
         Position.Current := Next_Virtual_Placement (Position.Current);
      end if;
   end Advance;

   procedure Advance (Position : in out Conventional_Cursor) is
   begin
      if Position.Current /= null then
         Position.Previous := Position.Current;
         Position.Current := Next_Conventional_Placement (Position.Current);
      end if;
   end Advance;

   procedure Validate_Delete (R : Renderer; Position : Virtual_Cursor) is
   begin
      if Position.Current = null then
         raise Constraint_Error with "cannot delete an empty placement cursor";
      end if;
      Terminal.App.Image_Placements.Validate_Remove
        (R.Graphics_State.Resources.Placements,
         Position.Previous,
         Position.Current);
   end Validate_Delete;

   procedure Validate_Delete (R : Renderer; Position : Conventional_Cursor) is
   begin
      if Position.Current = null then
         raise Constraint_Error with "cannot delete an empty placement cursor";
      end if;
      Terminal.App.Image_Placements.Validate_Remove
        (R.Graphics_State.Resources.Placements,
         Position.Previous,
         Position.Current);
   end Validate_Delete;

   procedure Delete
     (R : in out Renderer; Position : in out Virtual_Cursor)
   is
      Following : Virtual_Placement_Access;
   begin
      if Position.Current = null then
         raise Constraint_Error with "cannot delete an empty placement cursor";
      end if;
      Remove_Virtual_Placement
        (R, Position.Previous, Position.Current, Following);
      Position.Current := Following;
   end Delete;

   procedure Delete
     (R : in out Renderer; Position : in out Conventional_Cursor)
   is
      Following : Conventional_Placement_Access;
   begin
      if Position.Current = null then
         raise Constraint_Error with "cannot delete an empty placement cursor";
      end if;
      Remove_Conventional_Placement
        (R, Position.Previous, Position.Current, Following);
      Position.Current := Following;
   end Delete;

   procedure Invalidate_Placement_Index (R : in out Renderer) is
   begin
      R.Frame_State.Placement_Index_Dirty := True;
      R.Graphics_State.Animation_Schedule_Valid := False;
   end Invalidate_Placement_Index;

   procedure Rebuild_Placement_Index (R : in out Renderer) is
   begin
      Terminal.App.Placeholder_Index.Build
        (R.Frame_State.Placement_Index,
         First_Virtual_Placement (R),
         First_Conventional_Placement (R),
         R.Graphics_State.Resources.Image_Objects);
      R.Frame_State.Placement_Index_Dirty := False;
   end Rebuild_Placement_Index;

   procedure Prepare_Index
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot) is
   begin
      if R.Frame_State.Placement_Index_Dirty then
         Rebuild_Placement_Index (R);
      end if;
      Terminal.App.Placeholder_Index.Index_Cells
        (R.Frame_State.Placement_Index, Snapshot);
   exception
      when Storage_Error =>
         Invalidate_Placement_Index (R);
         R.Graphics_State.Transaction.Event_Tracking_Failed := True;
   end Prepare_Index;

   procedure Prepend_Virtual_Placement
     (R : in out Renderer; Placement : in out Virtual_Placement_Access) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Prepend
        (R.Graphics_State.Resources.Placements, Placement);
      Placement := null;
   end Prepend_Virtual_Placement;

   procedure Prepend_Conventional_Placement
     (R : in out Renderer; Placement : in out Conventional_Placement_Access) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Prepend
        (R.Graphics_State.Resources.Placements, Placement);
      Placement := null;
   end Prepend_Conventional_Placement;

   procedure Remove_Virtual_Placement
     (R        : in out Renderer;
      Previous : Virtual_Placement_Access;
      Current  : in out Virtual_Placement_Access;
      Next     : out Virtual_Placement_Access) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Remove
        (R.Graphics_State.Resources.Placements, Previous, Current, Next);
   end Remove_Virtual_Placement;

   procedure Remove_Conventional_Placement
     (R        : in out Renderer;
      Previous : Conventional_Placement_Access;
      Current  : in out Conventional_Placement_Access;
      Next     : out Conventional_Placement_Access) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Remove
        (R.Graphics_State.Resources.Placements, Previous, Current, Next);
   end Remove_Conventional_Placement;

   function Find_Virtual_Placement
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Value is
     (Value_Of
        (Terminal.App.Image_Placements.Find_Virtual
           (R.Graphics_State.Resources.Placements, Stream_ID, Alternate_Screen,
            Screen_Generation, Image_ID, Placement_ID)));

   function Find_Addressed_Virtual_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Value is
     (Value_Of
        (Terminal.App.Image_Placements.Find_Addressed_Virtual
           (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID,
            Placement_ID)));

   procedure Update_Addressed_Virtual_Placement
     (R            : in out Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Process      : not null access procedure
        (Placement : in out Virtual_Placement_State))
   is
      Placement : constant Virtual_Placement_Access :=
        Terminal.App.Image_Placements.Find_Addressed_Virtual
          (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID,
           Placement_ID);
   begin
      if Placement = null then
         raise Constraint_Error with "addressed virtual placement is missing";
      end if;
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update
        (R.Graphics_State.Resources.Placements, Placement, Process);
   end Update_Addressed_Virtual_Placement;

   function Has_Virtual_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean is
     (Terminal.App.Image_Placements.Has_Virtual
        (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID));

   function Find_Conventional_Placement
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Value is
     (Value_Of
        (Terminal.App.Image_Placements.Find_Conventional
           (R.Graphics_State.Resources.Placements, Stream_ID, Alternate_Screen,
            Screen_Generation, Image_ID, Placement_ID)));

   function Find_Addressed_Conventional_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Value is
     (Value_Of
        (Terminal.App.Image_Placements.Find_Addressed_Conventional
           (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID,
            Placement_ID)));

   procedure Update_Addressed_Conventional_Placement
     (R            : in out Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Process      : not null access procedure
        (Placement : in out Conventional_Placement_State))
   is
      Placement : constant Conventional_Placement_Access :=
        Terminal.App.Image_Placements.Find_Addressed_Conventional
          (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID,
           Placement_ID);
   begin
      if Placement = null then
         raise Constraint_Error with
           "addressed conventional placement is missing";
      end if;
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Update
        (R.Graphics_State.Resources.Placements, Placement, Process);
   end Update_Addressed_Conventional_Placement;

   function Has_Conventional_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean is
     (Terminal.App.Image_Placements.Has_Conventional
        (R.Graphics_State.Resources.Placements, Stream_ID, Image_ID));

   function Has_Image_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean is
     (Has_Virtual_Placement (R, Stream_ID, Image_ID)
      or else Has_Conventional_Placement (R, Stream_ID, Image_ID));

   function Has_Image_Placement
     (R : in out Renderer; Object : Image_Object_Access) return Boolean
   is
   begin
      if Object = null then
         return False;
      end if;
      if R.Frame_State.Placement_Index_Dirty then
         Rebuild_Placement_Index (R);
      end if;
      return Terminal.App.Placeholder_Index.Has_Object_Placement
        (R.Frame_State.Placement_Index,
         Object.Stream_ID,
         Object.Storage_Order);
   end Has_Image_Placement;

   function Has_Conventional_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Boolean
   is
      Current : Conventional_Placement_Access :=
        First_Conventional_Placement (R);
   begin
      while Current /= null loop
         declare
            S : constant Conventional_Placement_State :=
              Terminal.App.Image_Placements.State (Current);
         begin
            if S.Stream_ID = Stream_ID
              and then S.Image_Storage_Order = Storage_Order
            then
               return True;
            end if;
         end;
         Current := Next_Conventional_Placement (Current);
      end loop;
      return False;
   end Has_Conventional_Storage_Order;

   function Has_Implicit_Virtual
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Storage_Order     : Interfaces.Unsigned_64) return Boolean
   is
      Current : Virtual_Placement_Access := First_Virtual_Placement (R);
   begin
      while Current /= null loop
         declare
            S : constant Virtual_Placement_State :=
              Terminal.App.Image_Placements.State (Current);
         begin
            if S.Stream_ID = Stream_ID
              and then S.Alternate_Screen = Alternate_Screen
              and then S.Screen_Generation = Screen_Generation
              and then S.Image_ID = Image_ID
              and then S.Placement_ID = 0
              and then S.Image_Storage_Order = Storage_Order
            then
               return True;
            end if;
         end;
         Current := Next_Virtual_Placement (Current);
      end loop;
      return False;
   end Has_Implicit_Virtual;

   function Has_Implicit_Conventional
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Storage_Order     : Interfaces.Unsigned_64) return Boolean
   is
      Current : Conventional_Placement_Access :=
        First_Conventional_Placement (R);
   begin
      while Current /= null loop
         declare
            S : constant Conventional_Placement_State :=
              Terminal.App.Image_Placements.State (Current);
         begin
            if S.Stream_ID = Stream_ID
              and then S.Alternate_Screen = Alternate_Screen
              and then S.Screen_Generation = Screen_Generation
              and then S.Image_ID = Image_ID
              and then S.Placement_ID = 0
              and then S.Image_Storage_Order = Storage_Order
            then
               return True;
            end if;
         end;
         Current := Next_Conventional_Placement (Current);
      end loop;
      return False;
   end Has_Implicit_Conventional;

   procedure For_Each_Visible_Image_Object
     (R       : Renderer;
      Process : not null access procedure
        (Stream_ID     : Terminal.Core.Graphics_Stream_ID;
         Storage_Order : Interfaces.Unsigned_64))
   is
      function Visible
        (Stream_ID         : Terminal.Core.Graphics_Stream_ID;
         Alternate_Screen  : Boolean;
         Screen_Generation : Terminal.Core.Graphics_Screen_Generation)
         return Boolean
      is
      begin
         for I in 1 .. R.Graphics_State.Visible_View_Count loop
            if R.Graphics_State.Visible_Views (I).Stream_ID = Stream_ID
              and then R.Graphics_State.Visible_Views (I).Alternate_Screen =
                Alternate_Screen
              and then R.Graphics_State.Visible_Views (I).Screen_Generation =
                Screen_Generation
            then
               return True;
            end if;
         end loop;
         return False;
      end Visible;

      Virtual_Current : Virtual_Placement_Access := First_Virtual_Placement (R);
      Conventional_Current : Conventional_Placement_Access :=
        First_Conventional_Placement (R);
   begin
      while Virtual_Current /= null loop
         declare
            S : constant Virtual_Placement_State :=
              Terminal.App.Image_Placements.State (Virtual_Current);
         begin
            if Visible
              (S.Stream_ID, S.Alternate_Screen, S.Screen_Generation)
            then
               Process (S.Stream_ID, S.Image_Storage_Order);
            end if;
         end;
         Virtual_Current := Next_Virtual_Placement (Virtual_Current);
      end loop;
      while Conventional_Current /= null loop
         declare
            S : constant Conventional_Placement_State :=
              Terminal.App.Image_Placements.State (Conventional_Current);
         begin
            if Visible
              (S.Stream_ID, S.Alternate_Screen, S.Screen_Generation)
            then
               Process (S.Stream_ID, S.Image_Storage_Order);
            end if;
         end;
         Conventional_Current :=
           Next_Conventional_Placement (Conventional_Current);
      end loop;
   end For_Each_Visible_Image_Object;

   function Parent_Placement_Exists
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID) return Boolean is
     (Find_Conventional_Placement
        (R, Stream_ID, Alternate_Screen, Screen_Generation, Image_ID,
         Placement_ID).Exists
      or else Find_Virtual_Placement
        (R, Stream_ID, Alternate_Screen, Screen_Generation, Image_ID,
         Placement_ID).Exists);

   procedure Delete_Virtual_Placements
     (R               : in out Renderer;
      Stream_ID       : Terminal.Core.Graphics_Stream_ID;
      Image_ID        : Terminal.Core.Graphics_ID;
      Placement_ID    : Terminal.Core.Graphics_ID := 0;
      Match_Placement : Boolean := False)
   is
      Previous : Virtual_Placement_Access := null;
      Current  : Virtual_Placement_Access := First_Virtual_Placement (R);
      Position : Virtual_Cursor := First_Virtual (R);
   begin
      --  Validate the complete match set before unlinking its first member.
      --  A corrupt key/address/image index must leave the live lists intact.
      while Has_Element (Position) loop
         declare
            S : constant Virtual_Placement_State := Element (Position);
         begin
            if S.Stream_ID = Stream_ID
              and then (Image_ID = 0 or else S.Image_ID = Image_ID)
              and then
                (not Match_Placement or else S.Placement_ID = Placement_ID)
            then
               Validate_Delete (R, Position);
            end if;
            Advance (Position);
         end;
      end loop;

      while Current /= null loop
         declare
            Following : Virtual_Placement_Access :=
              Next_Virtual_Placement (Current);
            S : constant Virtual_Placement_State :=
              Terminal.App.Image_Placements.State (Current);
            Match : constant Boolean :=
              S.Stream_ID = Stream_ID
              and then (Image_ID = 0 or else S.Image_ID = Image_ID)
              and then
                (not Match_Placement
                 or else S.Placement_ID = Placement_ID);
         begin
            if Match then
               Remove_Virtual_Placement (R, Previous, Current, Following);
            else
               Previous := Current;
            end if;
            Current := Following;
         end;
      end loop;
   end Delete_Virtual_Placements;

   procedure Delete_Conventional_If
     (R             : in out Renderer;
      Matches       : not null access function
        (Placement : Conventional_Placement_State) return Boolean;
      Before_Delete : access procedure
        (Placement : Conventional_Placement_State) := null)
   is
      Position : Conventional_Cursor := First_Conventional (R);
      type Match_Array is array
        (Positive range 1 .. Max_Kitty_Placements) of Boolean;
      Matched : Match_Array := (others => False);
      Candidate_Index : Natural := 0;
      Position_Index  : Natural := 0;
   begin
      --  Validate every matching node before publishing the first removal.
      --  Preserve that exact match set for the mutation pass: removing a
      --  relative-placement parent must not change whether its child is part
      --  of the transaction.
      while Has_Element (Position) loop
         Candidate_Index := Candidate_Index + 1;
         Matched (Candidate_Index) := Matches (Element (Position));
         if Matched (Candidate_Index) then
            Validate_Delete (R, Position);
         end if;
         Advance (Position);
      end loop;

      --  Run all preparation callbacks before publishing a removal.  Callers
      --  may collect side data here, and an exception must still leave the
      --  placement list untouched.
      if Before_Delete /= null then
         Position := First_Conventional (R);
         Position_Index := 0;
         while Has_Element (Position) loop
            Position_Index := Position_Index + 1;
            if Matched (Position_Index) then
               Before_Delete (Element (Position));
            end if;
            Advance (Position);
         end loop;
      end if;

      Position := First_Conventional (R);
      Position_Index := 0;
      while Has_Element (Position) loop
         Position_Index := Position_Index + 1;
         if Matched (Position_Index) then
            Delete (R, Position);
         else
            Advance (Position);
         end if;
      end loop;
   end Delete_Conventional_If;

   procedure Delete_Conventional_Placements
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID := 0;
      Match_Placement   : Boolean := False;
      Match_Protocol    : Boolean := True;
      Protocol          : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Match_Screen      : Boolean := False;
      Alternate_Screen  : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0)
   is
      function Matches
        (S : Conventional_Placement_State) return Boolean is
        (S.Stream_ID = Stream_ID
         and then (Image_ID = 0 or else S.Image_ID = Image_ID)
         and then (not Match_Protocol or else S.Protocol = Protocol)
         and then
           (not Match_Screen
            or else
              (S.Alternate_Screen = Alternate_Screen
               and then S.Screen_Generation = Screen_Generation))
         and then
           (not Match_Placement or else S.Placement_ID = Placement_ID));
   begin
      Delete_Conventional_If (R, Matches'Access);
   end Delete_Conventional_Placements;

   procedure Move_Relative_Descendants
     (R                   : in out Renderer;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation) is
   begin
      Invalidate_Placement_Index (R);
      Terminal.App.Image_Placements.Move_Relative_Descendants
        (R.Graphics_State.Resources.Placements, Stream_ID, Parent_Image_ID,
         Parent_Placement_ID, Alternate_Screen, Screen_Generation,
         Max_Relative_Placement_Depth);
   end Move_Relative_Descendants;

   function Resolve_Placement_Geometry
     (R            : Renderer;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry
   is
      Result : constant Placement_Geometry :=
        Terminal.App.Image_Placements.Resolve
          (R.Text_State.CW, R.Text_State.CH, Pixel_Width, Pixel_Height, Header);
      Limit : constant Positive :=
        R.Graphics_State.Policy.Limits.Pixel_Dimension;
   begin
      if not Result.Valid
        or else Result.Columns > Limit
        or else Result.Rows > Limit
        or else Result.Draw_Width > Limit
        or else Result.Draw_Height > Limit
      then
         return (others => <>);
      end if;
      return Result;
   end Resolve_Placement_Geometry;

   function Resolve_Placement_Geometry
     (R      : Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry is
     (if Object = null then (others => <>)
      else Resolve_Placement_Geometry
        (R, Object.Pixel_Width, Object.Pixel_Height, Header));
end Terminal.App.Renderer.Placement_State;
