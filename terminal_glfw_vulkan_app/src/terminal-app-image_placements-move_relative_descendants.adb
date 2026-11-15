separate (Terminal.App.Image_Placements)
procedure Move_Relative_Descendants
  (Container           : in out Store;
   Stream_ID           : Terminal.Core.Graphics_Stream_ID;
   Parent_Image_ID     : Terminal.Core.Graphics_ID;
   Parent_Placement_ID : Terminal.Core.Graphics_ID;
   Alternate_Screen    : Boolean;
   Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
   Maximum_Depth       : Positive)
is
   type Relative_Key is record
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
   end record;

   function Hash (Key : Relative_Key) return Ada.Containers.Hash_Type is
      use type Ada.Containers.Hash_Type;
   begin
      return
        Ada.Containers.Hash_Type'Mod (Key.Image_ID) * 16#0100_0193#
        xor Ada.Containers.Hash_Type'Mod (Key.Placement_ID);
   end Hash;

   function Equivalent (Left, Right : Relative_Key) return Boolean is
     (Left.Image_ID = Right.Image_ID
      and then Left.Placement_ID = Right.Placement_ID);

   package Depth_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Relative_Key,
      Element_Type    => Natural,
      Hash            => Hash,
      Equivalent_Keys => Equivalent);

   Reachable : Depth_Maps.Map;
   Root : constant Relative_Key :=
     (Image_ID => Parent_Image_ID, Placement_ID => Parent_Placement_ID);
   Changed : Boolean;

   procedure Move_Reachable (Item : in out Conventional_Placement_State) is
      Parent : constant Relative_Key :=
        (Item.Parent_Image_ID, Item.Parent_Placement_ID);
   begin
      if Item.Stream_ID = Stream_ID
        and then Item.Protocol = Terminal.App.Render_Model.Image_Kitty
        and then Item.Parent_Image_ID /= 0
        and then Item.Parent_Placement_ID /= 0
        and then Reachable.Contains (Parent)
        and then Reachable.Element (Parent) < Maximum_Depth
      then
         Item.Alternate_Screen := Alternate_Screen;
         Item.Screen_Generation := Screen_Generation;
      end if;
   end Move_Reachable;
begin
   if Parent_Image_ID = 0 or else Parent_Placement_ID = 0 then
      return;
   end if;

   Reachable.Reserve_Capacity
     (Ada.Containers.Count_Type (Container.Placement_Count + 1));
   Reachable.Insert (Root, 0);

   --  Discover identities without mutating the list.  Each pass scans the
   --  list once and hash lookup bounds total work by depth * placements,
   --  independent of descendant fan-out.
   for Pass in 1 .. Maximum_Depth loop
      Changed := False;
      declare
         Current : Conventional_Placement_Access :=
           Container.Conventional_Head;
      begin
         while Current /= null loop
            if Current.State.Stream_ID = Stream_ID
              and then Current.State.Protocol =
                Terminal.App.Render_Model.Image_Kitty
              and then Current.State.Parent_Image_ID /= 0
              and then Current.State.Parent_Placement_ID /= 0
            then
               declare
                  Parent : constant Relative_Key :=
                    (Current.State.Parent_Image_ID,
                     Current.State.Parent_Placement_ID);
                  Child : constant Relative_Key :=
                    (Current.State.Image_ID, Current.State.Placement_ID);
               begin
                  if Reachable.Contains (Parent)
                    and then Reachable.Element (Parent) < Maximum_Depth
                    and then Current.State.Placement_ID /= 0
                    and then not Reachable.Contains (Child)
                  then
                     Reachable.Insert
                       (Child, Reachable.Element (Parent) + 1);
                     Changed := True;
                  end if;
               end;
            end if;
            Current := Current.Link.Next_Link;
         end loop;
      end;
      exit when not Changed;
   end loop;

   --  Route identity changes through the common transactional update path.
   --  It prepares every new index before publishing either states or maps.
   Update_All (Container, Move_Reachable'Access);
end Move_Relative_Descendants;
