package body Terminal.App.Image_Store.Accounting is
   procedure Synchronize
     (Container : in out Store;
      Object    : Image_Object_Access)
   is
      New_Bytes       : Natural;
      New_Frames      : Natural;
      Remaining_Bytes : Natural;
      Remaining_Frames : Natural;
   begin
      if Object = null or else not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      New_Bytes := Owned_Bytes (Object.all);
      New_Frames := Object.State.Frame_Count - 1;
      Remaining_Bytes := Container.Bytes - Object.Accounted_Bytes;
      Remaining_Frames :=
        Container.Animation_Frames - Object.Accounted_Frames;
      Container.Bytes := Checked_Total (Remaining_Bytes, New_Bytes);
      Container.Animation_Frames :=
        Checked_Total (Remaining_Frames, New_Frames);
      Object.Accounted_Bytes := New_Bytes;
      Object.Accounted_Frames := New_Frames;
      Advance_Mutation_Epoch (Container);
   end Synchronize;
end Terminal.App.Image_Store.Accounting;
