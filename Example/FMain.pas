unit FMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.StdCtrls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.ListView.Types,
  FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base,
  FMX.ListView,
  System.Generics.Collections,
  Grijjy.TimerQueue;

type
  TFormMain = class(TForm)
    EditTimers: TEdit;
    ButtonStart: TButton;
    EditInterval: TEdit;
    LabelTimers: TLabel;
    LabelInterval: TLabel;
    ButtonStopAll: TButton;
    MemoLog: TMemo;
    ListViewTimers: TListView;
    ButtonStop: TButton;
    ButtonClear: TButton;
    ButtonSetInterval: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ButtonStartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ButtonStopAllClick(Sender: TObject);
    procedure ButtonStopClick(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ButtonSetIntervalClick(Sender: TObject);
  private
    { Private declarations }
    FTimerQueue: TgoTimerQueue;

    procedure OnTimer(const ASender: TObject);
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FTimerQueue := TgoTimerQueue.Create;
end;

procedure TFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FTimerQueue.Free;
end;

procedure TFormMain.ButtonStartClick(Sender: TObject);
var
  Timers, Interval: Integer;
  Handle: THandle;
  I: Integer;
  Item: TListViewItem;
begin
  Timers := StrToIntDef(EditTimers.Text, 1);
  Interval := StrToIntDef(EditInterval.Text, 1000);

  for I := 0 to Timers - 1 do
  begin
    Handle := FTimerQueue.Add(Interval, OnTimer);
    Item := ListViewTimers.Items.Add;
    Item.Tag := Handle;
    Item.Text := Format('Timer (%s, Interval=%d)',
      [UInt32(Handle).ToHexString, Interval]);
  end;
end;

procedure TFormMain.ButtonStopAllClick(Sender: TObject);
var
  Handle: THandle;
  Item: TListViewItem;
begin
  for Item in ListViewTimers.Items do
  begin
    Handle := Item.Tag;
    FTimerQueue.Release(Handle);
  end;
  ListViewTimers.Items.Clear;
end;

procedure TFormMain.ButtonStopClick(Sender: TObject);
var
  Handle: THandle;
begin
  if ListViewTimers.ItemIndex > -1 then
  begin
    Handle := ListViewTimers.Items[ListViewTimers.ItemIndex].Tag;
    FTimerQueue.Release(Handle);
    ListViewTimers.Items.Delete(ListViewTimers.ItemIndex);
  end;
end;

procedure TFormMain.ButtonSetIntervalClick(Sender: TObject);
var
  Interval: Integer;
  Handle: THandle;
begin
  Interval := StrToIntDef(EditInterval.Text, 1000);

  if ListViewTimers.ItemIndex > -1 then
  begin
    Handle := ListViewTimers.Items[ListViewTimers.ItemIndex].Tag;
    FTimerQueue.SetInterval(Handle, Interval);
  end;
end;

procedure TFormMain.ButtonClearClick(Sender: TObject);
begin
  MemoLog.Lines.Clear;
end;

procedure TFormMain.OnTimer(const ASender: TObject);
var
  S: String;
  Timer: TgoTimer;
begin
  Timer := ASender as TgoTimer;
  S := (Format('OnTimer (%s, Thread=%s, Interval=%d)',
    [UInt32(Timer.Handle).ToHexString, TThread.CurrentThread.ThreadID.ToHexString, Timer.Interval]));

  TThread.Synchronize(nil,
    procedure
    begin
      MemoLog.Lines.Add(S);
      MemoLog.GoToTextEnd;
    end);
end;

end.
