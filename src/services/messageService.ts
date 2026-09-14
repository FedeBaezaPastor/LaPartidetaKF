import { supabase } from "./supabaseClient";
import { safeStorage } from "../utils/safeStorage";
export interface Recipient {
  kind: "user" | "express";
  id: string;
  label: string;
}
export interface MessageDraft {
  id: string;
  title: string;
  body: string;
  status: "draft" | "sent";
  revision: number;
  recipients: Recipient[];
  author_alias: string;
  sent_by_alias?: string | null;
  created_at: string;
  sent_at: string | null;
  deliveries?: {
    id: string;
    recipient_label: string;
    recipient_id: string;
    kind: string;
    read_at: string | null;
  }[];
}
export interface MessageSummary {
  id: string;
  title: string;
  status: "draft" | "sent";
  author_alias: string;
  sent_by_alias?: string | null;
  created_at: string;
  sent_at: string | null;
  recipient_count: number;
  read_count: number;
}
export interface InboxItem {
  id: string;
  title: string;
  sent_at: string;
  read_at: string | null;
  body?: string;
}
export interface Inbox {
  messages: InboxItem[];
  total: number;
  unread: number;
}
async function rpc<T>(
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw error;
  return data as T;
}
const boxKey = "golf.express.message-box.v1";
interface Box {
  secret: string;
  id?: string;
}
let opening: Promise<Box> | null = null;
async function express<T>(input: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke("express-messages", {
    body: input,
  });
  if (error)
    throw new Error("No se pudo acceder al buzón. Inténtalo de nuevo.");
  return data as T;
}
async function prepareBox(): Promise<Box> {
  let box: Box | undefined;
  try {
    const saved = JSON.parse(safeStorage.getItem(boxKey) || "null");
    if (saved && /^[0-9a-f]{64}$/.test(saved.secret)) box = saved;
  } catch {
    /* Invalid local data is not a valid credential. */
  }
  if (!box) {
    box = {
      secret: Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) =>
        b.toString(16).padStart(2, "0"),
      ).join(""),
    };
    safeStorage.setItem(boxKey, JSON.stringify(box));
  }
  if (!box.id) {
    const result = await express<{ id: string }>({
      action: "register",
      secret: box.secret,
    });
    box.id = result.id;
    safeStorage.setItem(boxKey, JSON.stringify(box));
  }
  return box;
}
async function getBox() {
  if (!opening) {
    opening = (
      "locks" in navigator
        ? navigator.locks.request("golf-express-message-box", prepareBox)
        : prepareBox()
    ).finally(() => {
      opening = null;
    });
  }
  return opening;
}
// Check the caller's expected identity rather than falling back from a failed
// registered request to an Express mailbox belonging to this browser.
async function assertIdentity(userId: string | null) {
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();
  if (error || (session?.user.id ?? null) !== userId)
    throw new Error("La sesión ha cambiado. Actualiza la pantalla.");
}
export const messageService = {
  recipients: (search: string) =>
    rpc<Recipient[]>("admin_message_recipients", { p_search: search }),
  list: (page = 0) =>
    rpc<{ messages: MessageSummary[]; total: number }>("admin_list_messages", {
      p_page: page,
    }),
  detail: (id: string) => rpc<MessageDraft>("admin_get_message", { p_id: id }),
  save: (
    draft: Pick<
      MessageDraft,
      "id" | "title" | "body" | "recipients" | "revision"
    >,
  ) =>
    rpc<MessageDraft>("admin_save_message", {
      p_id: draft.id,
      p_title: draft.title,
      p_body: draft.body,
      p_recipients: draft.recipients.map(({ kind, id }) => ({ kind, id })),
      p_revision: draft.revision,
    }),
  send: (id: string, revision: number) =>
    rpc<MessageDraft>("admin_send_message", { p_id: id, p_revision: revision }),
  async inbox(
    userId: string | null,
    page = 0,
  ): Promise<Inbox & { boxId?: string }> {
    await assertIdentity(userId);
    if (userId) return rpc<Inbox>("my_message_inbox", { p_page: page });
    const box = await getBox();
    await assertIdentity(null);
    return {
      ...(await express<Inbox>({ action: "inbox", ...box, page })),
      boxId: box.id,
    };
  },
  async open(userId: string | null, id: string): Promise<InboxItem> {
    await assertIdentity(userId);
    if (userId) return rpc<InboxItem>("my_message_open", { p_delivery: id });
    const box = await getBox();
    await assertIdentity(null);
    return express<InboxItem>({ action: "open", ...box, delivery: id });
  },
};
