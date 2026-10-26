with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Image_Animation;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;

procedure Image_Store_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.App.Image_Store.Animation_Playback_State;
   use type Terminal.App.Image_Animation.Control_Result;

   package Store renames Terminal.App.Image_Store;
   package Themes renames Terminal.App.Image_Store.Themes;

   Container : aliased Store.Store;
   Original : Store.Image_Object_Access := null;
   Replacement : Store.Image_Object_Access := null;
   Pixel : Terminal.Common.Bytes.Byte_Array (1 .. 4);
   Valid : Boolean;
begin
   Store.Create_Object (Original);
   Store.Create_Object (Replacement);
   declare
      Indexed_Container : aliased Store.Store;
      Indexed_Object : Store.Image_Object_Access := null;
      Indexed_Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 => 7);
      Root_Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
   begin
      Store.Create_Object (Indexed_Object);
      Store.Link_New (Indexed_Container, Indexed_Object);
      Store.Install_Root
        (Indexed_Container, Indexed_Object,
         Stream_ID => 1, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Root_Data);
      Assert
        (Store.Root_Data (Indexed_Object) /= null,
         "installed root data is available through a read-only view");
      Store.Adopt_Indexed_Data
        (Indexed_Container, Indexed_Object, 8, 1, Indexed_Data);
      Assert
        (Indexed_Data = null
         and then Store.Indexed_Data_Length (Indexed_Object) = 1
         and then Store.Byte_Count (Indexed_Container) = 5,
         "indexed adoption transfers ownership and updates accounting");
      Assert
        (Store.Indexed_Data (Indexed_Object) /= null,
         "indexed data is available through a read-only view");
      Store.Delete_Object (Indexed_Container, Indexed_Object);
   end;

   Store.Link_New (Container, Original);
   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1 => 16#FF#, 2 => 0, 3 => 0, 4 => 16#FF#);
   begin
      Store.Install_Root
        (Container, Original, Stream_ID => 0, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Data);
   end;
   declare
      Rejected : Boolean := False;
      Other : Store.Store;
   begin
      begin
         Store.Link_New (Container, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "an owned object cannot be linked twice");
      Rejected := False;
      begin
         Store.Link_New (Other, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "an object cannot be linked into another store");
   end;
   Assert
     (Store.First (Container) = Original
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 4,
      "new object is owned and accounted");
   Assert
     (Store.Frame_Exists (Original, 1)
      and then Store.Frame_Bytes (Original, 1) = Store.Root_Data (Original),
      "root animation frame is resolved by the store");
   Store.Copy_Frame_To_RGBA (Original, 1, Pixel, Valid);
   Assert
     (Valid and then Pixel = Store.Root_Data (Original).all,
      "store copies the root RGBA frame");
   Assert
     (Original.Pixel_Width = 1 and then Original.Pixel_Height = 1,
      "installed dimensions are exposed read-only");

   Store.Link_Replacement (Container, Replacement, Original);
   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 8 => 0);
   begin
      Store.Install_Root
        (Container, Replacement, Stream_ID => 0, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 2, Pixel_Height => 1,
         Decoded_Length => 8, Row_Stride => 8, Usage_Hint => 0,
         Data => Data);
   end;
   declare
      Duplicate : Store.Image_Object_Access := null;
      Rejected : Boolean := False;
   begin
      Store.Create_Object (Duplicate);
      begin
         Store.Link_Replacement (Container, Duplicate, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "only one replacement may target an object");
      Store.Release_Unowned_Object (Duplicate);
   end;
   Assert
     (Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 12,
      "replacement accounting uses owned allocations, not metadata");

   Store.Delete_Replacement (Container, Replacement);
   Assert
     (Replacement = null
      and then Store.First (Container) = Original
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 4,
      "replacement rollback restores store accounting");

   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Operation : Store.Theme_Operation_Access;
   begin
      Themes.Create
        ((Target_Frame => 1, others => <>), Data, Operation);
      Themes.Adopt (Container, Original, Operation);
      Assert
        (Operation = null
         and then Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "theme history adoption transfers ownership and accounting");
   end;
   declare
      First : constant Store.Theme_Operation_Access :=
        Themes.First (Original);
      Duplicate : Store.Theme_Operation_Access := First;
      Rejected : Boolean := False;
   begin
      begin
         Themes.Append (Container, Original, Duplicate);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Duplicate = First,
         "theme history rejects an already-owned operation node");
   end;
   Themes.Clear (Container, Original);
   Assert
     (Themes.Count (Original) = 0
      and then Store.Byte_Count (Container) = 4,
      "clearing theme history restores accounting");

   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#31#);
      Operation : Store.Theme_Operation_Access;
      Transaction : Themes.Append_Transaction (Container'Access);
   begin
      Themes.Create
        ((Target_Frame => 1, others => <>), Data, Operation);
      Themes.Start (Transaction, Original, Operation);
      Assert
        (Operation = null
         and then Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "theme append transaction publishes provisional accounting");
      Themes.Rollback (Transaction);
      Assert
        (Themes.Count (Original) = 0
         and then Store.Byte_Count (Container) = 4,
         "theme append rollback restores ownership and accounting");
   end;

   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#32#);
      Operation : Store.Theme_Operation_Access;
      Transaction : Themes.Append_Transaction (Container'Access);
   begin
      Themes.Create
        ((Target_Frame => 1, others => <>), Data, Operation);
      Themes.Start (Transaction, Original, Operation);
      Themes.Commit (Transaction);
      Themes.Rollback (Transaction);
      Assert
        (Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "committed theme append is not rolled back by cleanup");
      Themes.Clear (Container, Original);
   end;

   declare
      Before_Bytes : constant Natural := Store.Byte_Count (Container);
   begin
      declare
         Data : Terminal.App.Render_Model.Image_Data_Access :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#33#);
         Operation : Store.Theme_Operation_Access;
         Transaction : Themes.Append_Transaction (Container'Access);
      begin
         Themes.Create
           ((Target_Frame => 1, others => <>), Data, Operation);
         Themes.Start (Transaction, Original, Operation);
         Assert
           (Themes.Count (Original) = 1,
            "uncommitted theme append is provisionally visible");
      end;
      Assert
        (Themes.Count (Original) = 0
         and then Store.Byte_Count (Container) = Before_Bytes,
         "theme append finalizer automatically rolls back");
   end;

   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#7F#);
      Frame : Store.Image_Frame_Access;
   begin
      Store.Create_Frame (2, 40, 0, Data, Frame);
      Store.Append_Frame (Container, Original, Frame);
      Assert (Frame = null, "frame append transfers ownership");
   end;
   Assert
     (Store.Animation_Frame_Count (Container) = 1
      and then Store.Byte_Count (Container) = 8,
      "frame accounting follows actual store-owned allocations");
   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#22#);
      Duplicate : Store.Image_Frame_Access;
      Rejected : Boolean := False;
   begin
      Store.Create_Frame (2, 40, 0, Data, Duplicate);
      begin
         Store.Append_Frame (Container, Original, Duplicate);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Duplicate /= null,
         "frame append rejects duplicate or out-of-order numbers");
      Store.Release_Unowned_Frames (Duplicate);
   end;
   declare
      Other : Store.Store;
      Item : Store.Image_Object_Access := null;
      Root : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
      Data_2 : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Data_4 : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 2);
      Frame_2, Frame_4, Head, Tail : Store.Image_Frame_Access := null;
      Rejected : Boolean := False;
   begin
      Store.Create_Object (Item);
      Store.Link_New (Other, Item);
      Store.Install_Root
        (Other, Item, Stream_ID => 2, ID => 2, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Root);
      Store.Create_Frame (2, 40, 0, Data_2, Frame_2);
      Store.Create_Frame (4, 40, 0, Data_4, Frame_4);
      Store.Append_Unowned_Frame (Head, Tail, Frame_2);
      Store.Append_Unowned_Frame (Head, Tail, Frame_4);
      begin
         Store.Adopt_Frames (Other, Item, Head);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Head /= null
         and then Store.Frame_Count_Of (Item) = 1,
         "bulk frame adoption rejects numbering gaps transactionally");
      Store.Release_Unowned_Frames (Head);
      Store.Delete_Object (Other, Item);
   end;
   Store.Set_Playback (Original, Store.Animation_Running);
   Store.Set_Loop_Count (Original, 1);
   Store.Set_Loops_Completed (Original, Natural'Last);
   Store.Set_Current_Frame (Original, 2);
   Store.Set_Deadline (Original, True);
   Store.Set_Next_Frame_At (Original, Ada.Real_Time.Time_First);
   Assert
     (Terminal.App.Image_Animation.Apply_Control
        (Original,
         (Frame_Number => 2,
          Frame_Gap    => 25,
          Start_Frame  => 2,
          Loop_Count   => 3,
          State        => Terminal.App.Image_Animation.Running)) =
        Terminal.App.Image_Animation.Control_Ok
      and then Store.Frame_Gap (Original, 2) = 25
      and then Store.Current_Frame (Original.all) = 2
      and then Store.Loop_Count (Original.all) = 3
      and then Store.Playback (Original.all) = Store.Animation_Running,
      "protocol-neutral animation controls update store playback state");
   Store.Set_Playback (Original, Store.Animation_Running);
   Store.Set_Loop_Count (Original, 1);
   Store.Set_Loops_Completed (Original, Natural'Last);
   Store.Set_Current_Frame (Original, 2);
   Store.Set_Deadline (Original, True);
   Store.Set_Next_Frame_At (Original, Ada.Real_Time.Time_First);
   declare
      Advanced : constant Natural :=
        Terminal.App.Image_Animation.Advance
          (Original, Ada.Real_Time.Clock);
   begin
      Assert
        (Advanced > 0
         and then Original.Loops_Completed = Natural'Last,
         "infinite animation playback never increments its loop counter");
   end;
   Assert
     (Store.Root_Data (Original) /= null,
      "store ownership exposes no mutable alias for root replacement");
   Store.Create_Object (Replacement);
   Store.Link_Replacement (Container, Replacement, Original);
   declare
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 8 => 0);
   begin
      Store.Install_Root
        (Container, Replacement,
         Stream_ID => Original.Stream_ID, ID => Original.ID, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 2, Pixel_Height => 1,
         Decoded_Length => 8, Row_Stride => 8, Usage_Hint => 0,
         Data => Data);
   end;
   Store.Delete_Replacement (Container, Original);
   Assert
     (Original = null
      and then Store.First (Container) = Replacement
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 8,
      "replacement commit transfers the logical object count");
   Store.Delete_Object (Container, Replacement);
   Assert
     (Replacement = null
      and then Store.First (Container) = null
      and then Store.Object_Count (Container) = 0
      and then Store.Byte_Count (Container) = 0,
      "object deletion releases store accounting");
end Image_Store_Smoke;
