procedure Terminal.App.Image_Placements.Bulk_Update_Algorithm
  (Container : in out Container_Type;
   Head      : Placement_Access;
   Capacity  : Ada.Containers.Count_Type;
   Process   : not null access procedure (Item : in out Placement_State))
is
   Candidates : State_Vectors.Vector;
   Identity_Changed : Boolean := False;
   Current : Placement_Access := Head;
begin
   Candidates.Reserve_Capacity (Capacity);
   while not Is_Null_Placement (Current) loop
      declare
         Original : constant Placement_State := State_Of (Current);
         Candidate : Placement_State := Original;
      begin
         Process (Candidate);
         Identity_Changed := Identity_Changed
           or else not Same_Identity_State (Original, Candidate);
         Candidates.Append (Candidate);
      end;
      Current := Next_Of (Current);
   end loop;
   if Identity_Changed then
      Rebuild (Container, Candidates);
   end if;
   Current := Head;
   for I in 1 .. Natural (Candidates.Length) loop
      Assign_State (Current, Candidates.Element (Positive (I)));
      Current := Next_Of (Current);
   end loop;
end Terminal.App.Image_Placements.Bulk_Update_Algorithm;
