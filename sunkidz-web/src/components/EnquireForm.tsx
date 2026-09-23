import { useState, type FormEvent } from "react";
import { branches, contact } from "../data/content";
import "./EnquireForm.css";

type FormState = {
  name: string;
  phone: string;
  childAge: string;
  branch: string;
  message: string;
};

const initial: FormState = {
  name: "",
  phone: "",
  childAge: "",
  branch: branches[0]?.id ?? "",
  message: "",
};

export function EnquireForm() {
  const [form, setForm] = useState<FormState>(initial);
  const [errors, setErrors] = useState<Partial<FormState>>({});
  const [sent, setSent] = useState(false);

  function update<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((f) => ({ ...f, [key]: value }));
    setErrors((e) => ({ ...e, [key]: undefined }));
  }

  function validate(): boolean {
    const next: Partial<FormState> = {};
    if (!form.name.trim()) next.name = "Please enter your name";
    if (!/^[6-9]\d{9}$/.test(form.phone.replace(/\s/g, "").replace(/^\+91/, ""))) {
      next.phone = "Enter a valid 10-digit mobile number";
    }
    if (!form.childAge.trim()) next.childAge = "Tell us your child’s age";
    if (!form.branch) next.branch = "Select a branch";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!validate()) return;

    const branchName =
      branches.find((b) => b.id === form.branch)?.name ?? form.branch;
    const subject = encodeURIComponent(`SunKidz enquiry — ${form.name}`);
    const body = encodeURIComponent(
      [
        `Name: ${form.name}`,
        `Phone: ${form.phone}`,
        `Child's age: ${form.childAge}`,
        `Preferred branch: ${branchName}`,
        "",
        form.message || "(No additional message)",
      ].join("\n"),
    );

    window.location.href = `mailto:${contact.email}?subject=${subject}&body=${body}`;
    setSent(true);
  }

  if (sent) {
    return (
      <div className="enquire-success" role="status">
        <h3>Thank you</h3>
        <p>
          Your email client should open with the enquiry ready to send. You can
          also call us at{" "}
          <a href={`tel:${contact.phoneTel}`}>{contact.phones[0]}</a>.
        </p>
        <button
          type="button"
          className="btn btn-secondary"
          onClick={() => {
            setSent(false);
            setForm(initial);
          }}
        >
          Send another
        </button>
      </div>
    );
  }

  return (
    <form className="enquire-form" onSubmit={onSubmit} noValidate>
      <div className="field">
        <label htmlFor="name">Parent / guardian name</label>
        <input
          id="name"
          name="name"
          autoComplete="name"
          value={form.name}
          onChange={(e) => update("name", e.target.value)}
          aria-invalid={!!errors.name}
        />
        {errors.name && <span className="field-error">{errors.name}</span>}
      </div>

      <div className="field">
        <label htmlFor="phone">Phone</label>
        <input
          id="phone"
          name="phone"
          type="tel"
          autoComplete="tel"
          placeholder="10-digit mobile"
          value={form.phone}
          onChange={(e) => update("phone", e.target.value)}
          aria-invalid={!!errors.phone}
        />
        {errors.phone && <span className="field-error">{errors.phone}</span>}
      </div>

      <div className="field-row">
        <div className="field">
          <label htmlFor="childAge">Child’s age</label>
          <input
            id="childAge"
            name="childAge"
            placeholder="e.g. 3 years"
            value={form.childAge}
            onChange={(e) => update("childAge", e.target.value)}
            aria-invalid={!!errors.childAge}
          />
          {errors.childAge && (
            <span className="field-error">{errors.childAge}</span>
          )}
        </div>

        <div className="field">
          <label htmlFor="branch">Preferred branch</label>
          <select
            id="branch"
            name="branch"
            value={form.branch}
            onChange={(e) => update("branch", e.target.value)}
            aria-invalid={!!errors.branch}
          >
            {branches.map((b) => (
              <option key={b.id} value={b.id}>
                {b.name}
              </option>
            ))}
          </select>
          {errors.branch && (
            <span className="field-error">{errors.branch}</span>
          )}
        </div>
      </div>

      <div className="field">
        <label htmlFor="message">Message (optional)</label>
        <textarea
          id="message"
          name="message"
          rows={4}
          value={form.message}
          onChange={(e) => update("message", e.target.value)}
          placeholder="Program of interest, timing, questions…"
        />
      </div>

      <button type="submit" className="btn btn-primary">
        Send enquiry
      </button>
    </form>
  );
}
