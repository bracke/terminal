separate (Terminal.App.Image_Store_Smoke)
procedure Run_Frame_Cases is
   Container : aliased Store.Store;
   Original  : Store.Image_Object_Access := null;
begin
   Store.Create_Object (Original);
   Store.Link_New (Container, Original);
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1 => 16#FF#, 2 => 0, 3 => 0, 4 => 16#FF#);
   begin
      Install_Root
        (Container, Original, Stream_ID => 0, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Data);
   end;
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#7F#);
      Frame : Store.Image_Frame_Access;
   begin
      Create_Frame (2, 40, 0, Data, Frame);
      Frames.Append (Container, Original, Frame);
      Assert (Frame = null, "frame append transfers ownership");
   end;
   Assert
     (Store.Animation_Frame_Count (Container) = 1
      and then Store.Byte_Count (Container) = 8,
      "frame accounting follows actual store-owned allocations");
   declare
      Info : Frames.Frame_Descriptor := Frames.Descriptor (Original, 2);
   begin
      Assert
        (Info.Number = 2
         and then Info.Gap_MS = 40
         and then Info.Usage_Hint = 0
         and then Info.Length = 4,
         "owned frames expose immutable number-addressed descriptors");
      Assert
        (Frames.Set_Gap (Container, Original, 2, 25)
         and then Frames.Set_Usage_Hint (Container, Original, 2, 1),
         "owned frame metadata mutates through object and frame number");
      Info := Frames.Descriptor (Original, 2);
      Assert
        (Info.Gap_MS = 25 and then Info.Usage_Hint = 1,
         "owned frame descriptors reflect checked metadata mutations");
   end;
   declare
      Borrow : Store.Data_Borrow;
      Adopt_Borrow : Store.Data_Borrow;
      Adopt_Store : Store.Store;
      Adopt_Object : Store.Image_Object_Access := null;
      Adopt_Root : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
      Append_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#33#);
      Adopt_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#44#);
      Append_Frame, Adopt_Frame, Head, Tail : Store.Image_Frame_Access := null;
      Append_Rejected, Adopt_Rejected : Boolean := False;
   begin
      Store.Create_Object (Adopt_Object);
      Store.Link_New (Adopt_Store, Adopt_Object);
      Install_Root
        (Adopt_Store, Adopt_Object,
         Stream_ID => 1, ID => 99, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Adopt_Root);
      Create_Frame (3, 40, 0, Append_Data, Append_Frame);
      Create_Frame (2, 40, 0, Adopt_Data, Adopt_Frame);
      Frames.Append_Unowned (Head, Tail, Adopt_Frame);
      Store.Borrow (Borrow, Original);
      Store.Borrow (Adopt_Borrow, Adopt_Object);
      begin
         Frames.Append (Container, Original, Append_Frame);
      exception
         when Program_Error => Append_Rejected := True;
      end;
      begin
         Frames.Adopt (Adopt_Store, Adopt_Object, Head);
      exception
         when Program_Error => Adopt_Rejected := True;
      end;
      Assert
        (Append_Rejected and then Adopt_Rejected
         and then Append_Frame /= null and then Head /= null,
         "active frame borrows reject append and bulk adoption");
      Frames.Release_Unowned (Append_Frame);
      Frames.Release_Unowned (Head);
      Store.Release (Adopt_Borrow);
      Store.Delete_Object (Adopt_Store, Adopt_Object);
   end;
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#22#);
      Duplicate : Store.Image_Frame_Access;
      Rejected : Boolean := False;
   begin
      Create_Frame (2, 40, 0, Data, Duplicate);
      begin
         Frames.Append (Container, Original, Duplicate);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Duplicate /= null,
         "frame append rejects duplicate or out-of-order numbers");
      Frames.Release_Unowned (Duplicate);
   end;
   declare
      Other : Store.Store;
      Item : Store.Image_Object_Access := null;
      Root : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
      Data_2 : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Data_4 : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 2);
      Frame_2, Frame_4, Head, Tail : Store.Image_Frame_Access := null;
      Rejected : Boolean := False;
   begin
      Store.Create_Object (Item);
      Store.Link_New (Other, Item);
      Install_Root
        (Other, Item, Stream_ID => 2, ID => 2, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Root);
      Assert
        (not Frames.Set_Gap (Container, Item, 1, 99)
         and then not Frames.Set_Usage_Hint (Container, Item, 1, 7)
         and then Frames.Gap (Item, 1) /= 99,
         "frame metadata rejects objects owned by another store");
      Create_Frame (2, 40, 0, Data_2, Frame_2);
      Create_Frame (4, 40, 0, Data_4, Frame_4);
      Frames.Append_Unowned (Head, Tail, Frame_2);
      Frames.Append_Unowned (Head, Tail, Frame_4);
      begin
         Frames.Adopt (Other, Item, Head);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Head /= null
         and then Frames.Count (Item) = 1,
         "bulk frame adoption rejects numbering gaps transactionally");
      Frames.Release_Unowned (Head);
      Store.Delete_Object (Other, Item);
   end;
   Playback.Replace
     (Original,
      (Root_Gap_MS     => Playback.Root_Gap_MS (Original.all),
       Current_Frame   => 2,
       Mode            => Store.Animation_Running,
       Loop_Count      => 1,
       Loops_Completed => 0,
       Next_Frame_At   => Ada.Real_Time.Time_First,
       Deadline_Set    => True));
   Assert
     (Terminal.App.Image_Animation.Apply_Control
        (Container,
         Original,
         (Frame_Number => 2,
          Frame_Gap    => 25,
          Start_Frame  => 2,
          Loop_Count   => 3,
          State        => Terminal.App.Image_Animation.Running)) =
        Terminal.App.Image_Animation.Control_Ok
      and then Frames.Gap (Original, 2) = 25
      and then Playback.Current_Frame (Original.all) = 2
      and then Playback.Loop_Count (Original.all) = 3
      and then Playback.Playback (Original.all) = Store.Animation_Running,
      "protocol-neutral animation controls update store playback state");
   Playback.Replace
     (Original,
      (Root_Gap_MS     => Playback.Root_Gap_MS (Original.all),
       Current_Frame   => 2,
       Mode            => Store.Animation_Running,
       Loop_Count      => 1,
       Loops_Completed => 0,
       Next_Frame_At   => Ada.Real_Time.Time_First,
       Deadline_Set    => True));
   declare
      Advanced : constant Natural :=
        Terminal.App.Image_Animation.Advance
          (Original, Ada.Real_Time.Clock);
   begin
      Assert
        (Advanced > 0
         and then Playback.Loops_Completed (Original.all) = 0,
         "infinite animation playback never increments its loop counter");
   end;
   declare
      Rejected_Stopped_Deadline : Boolean := False;
      Rejected_Infinite_Count : Boolean := False;
      State : Playback.State := Playback.Value (Original.all);
   begin
      State.Mode := Store.Animation_Stopped;
      State.Deadline_Set := True;
      begin
         Playback.Replace (Original, State);
      exception
         when Constraint_Error =>
            Rejected_Stopped_Deadline := True;
      end;
      State := Playback.Value (Original.all);
      State.Loop_Count := 1;
      State.Loops_Completed := 1;
      begin
         Playback.Replace (Original, State);
      exception
         when Constraint_Error =>
            Rejected_Infinite_Count := True;
      end;
      Assert
        (Rejected_Stopped_Deadline and then Rejected_Infinite_Count,
         "playback replacement rejects contradictory state");
   end;
   Store.Delete_Object (Container, Original);
end Run_Frame_Cases;
