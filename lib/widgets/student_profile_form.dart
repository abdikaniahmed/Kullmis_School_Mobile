import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            value: gender,
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
            value: studentType,
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
            value: feeType,
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
}
