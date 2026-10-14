import 'package:flutter/material.dart';
import 'student_edit_design.dart';

class StudentProfileForm extends StatelessWidget {
  const StudentProfileForm({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.secondPhoneController,
    required this.addressController,
    required this.busAssignController,
    required this.bloodTypeController,
    required this.gender,
    required this.studentType,
    required this.feeType,
    required this.onGenderChanged,
    required this.onStudentTypeChanged,
    required this.onFeeTypeChanged,
    required this.onSubmit,
    required this.submitLabel,
    required this.loading,
    this.onCancel,
    this.editDesign = false,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController secondPhoneController;
  final TextEditingController addressController;
  final TextEditingController busAssignController;
  final TextEditingController bloodTypeController;
  final String? gender;
  final String? studentType;
  final String? feeType;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onStudentTypeChanged;
  final ValueChanged<String?> onFeeTypeChanged;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool loading;
  final VoidCallback? onCancel;
  final bool editDesign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (editDesign) return _editForm();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student Profile', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Student Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: secondPhoneController,
            decoration: const InputDecoration(
              labelText: 'Second Phone (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Select gender')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: studentType,
            decoration: const InputDecoration(
              labelText: 'Student Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'boarding', child: Text('Boarding')),
            ],
            onChanged: onStudentTypeChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: feeType,
            decoration: const InputDecoration(
              labelText: 'Fee Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(
                value: 'full_scholarship',
                child: Text('Full Scholarship'),
              ),
              DropdownMenuItem(value: 'partial', child: Text('Partial')),
            ],
            onChanged: onFeeTypeChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: addressController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: busAssignController,
            decoration: const InputDecoration(
              labelText: 'Bus Assigned (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bloodTypeController,
            decoration: const InputDecoration(
              labelText: 'Blood Type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null) ...[
                OutlinedButton(
                  onPressed: loading ? null : onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
              ],
              FilledButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editForm() {
    Widget text(String label, IconData icon, TextEditingController controller,
            {bool required = false,
            bool phone = false,
            bool address = false}) =>
        StudentField(
            label: label,
            icon: icon,
            required: required,
            child: TextField(
                controller: controller,
                keyboardType: phone
                    ? TextInputType.phone
                    : address
                        ? TextInputType.multiline
                        : TextInputType.text,
                minLines: address ? 2 : 1,
                maxLines: address ? 4 : 1,
                decoration:
                    studentInput(hint: address ? 'Enter address...' : null)));
    Widget dropdown(String label, IconData icon, String? value,
            Map<String, String> options, ValueChanged<String?> changed) =>
        StudentField(
            label: label,
            icon: icon,
            required: true,
            child: DropdownButtonFormField<String>(
                initialValue: options.containsKey(value) ? value : null,
                isExpanded: true,
                decoration: studentInput(),
                items: options.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: changed));
    final genderField = dropdown('Gender', Icons.male, gender,
        {'male': 'Male', 'female': 'Female'}, onGenderChanged);
    final typeField = dropdown('Student Type', Icons.school, studentType,
        {'normal': 'Normal', 'boarding': 'Boarding'}, onStudentTypeChanged);
    return StudentSection(
        title: 'Student Profile',
        subtitle: 'Basic personal information of the student.',
        icon: Icons.person,
        children: [
          text('Student Name', Icons.person, nameController, required: true),
          text('Phone Number', Icons.phone, phoneController, phone: true),
          text('Second Phone (Optional)', Icons.phone, secondPhoneController,
              phone: true),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 420
                  ? Column(children: [genderField, typeField])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(child: genderField),
                          const SizedBox(width: 16),
                          Expanded(child: typeField)
                        ])),
          dropdown(
              'Fee Type',
              Icons.storage,
              feeType,
              {
                'normal': 'Normal',
                'full_scholarship': 'Full Scholarship',
                'partial': 'Partial'
              },
              onFeeTypeChanged),
          StudentField(
              label: 'Blood Type (Optional)',
              icon: Icons.water_drop,
              child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: bloodTypeController,
                  builder: (context, value, _) =>
                      DropdownButtonFormField<String>(
                          key: ValueKey(bloodTypeController.text),
                          initialValue: bloodTypeController.text,
                          isExpanded: true,
                          decoration: studentInput(),
                          items: {
                            '': 'Not Specified',
                            for (final type in [
                              'A+',
                              'A-',
                              'B+',
                              'B-',
                              'AB+',
                              'AB-',
                              'O+',
                              'O-'
                            ])
                              type: type,
                            if (bloodTypeController.text.isNotEmpty)
                              bloodTypeController.text: bloodTypeController.text
                          }
                              .entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) {
                            bloodTypeController.text = v ?? '';
                          }))),
          text('Bus Assigned (Optional)', Icons.directions_bus,
              busAssignController),
          text('Address (Optional)', Icons.location_on, addressController,
              address: true),
        ]);
  }
}
